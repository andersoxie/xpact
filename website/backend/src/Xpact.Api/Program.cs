using System.Net;
using System.Text;
using System.Text.Json;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.Options;
using Xpact.Api;
using Xpact.Api.Workers;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<XpactOptions>(builder.Configuration.GetSection(XpactOptions.Section));
var xpact = builder.Configuration.GetSection(XpactOptions.Section).Get<XpactOptions>() ?? new XpactOptions();

// A document plus its envelope; anything larger is refused before it is read. Pasted text arrives as JSON,
// where escaping (quotes, line ends) can make a document up to twice as long, so the body may be 2x the document.
// The document itself is still checked against MaxDocumentBytes below.
long maxBody = 2L * xpact.MaxDocumentBytes + 64 * 1024;
builder.Services.Configure<KestrelServerOptions>(o =>
{
    o.Limits.MaxRequestBodySize = maxBody;
    o.AddServerHeader = false; // no "Server: Kestrel": do not advertise the server software
});

// Brotli/gzip for the page, its script and CSS, and the JSON results (about 300 KB less per first visit).
// No response carries a secret, so compression over HTTPS does not open a BREACH-style leak.
builder.Services.AddResponseCompression(o =>
{
    o.EnableForHttps = true;
    o.MimeTypes = Microsoft.AspNetCore.ResponseCompression.ResponseCompressionDefaults.MimeTypes
        .Concat(["image/svg+xml", "application/problem+json"]);
});
builder.Services.Configure<Microsoft.AspNetCore.ResponseCompression.BrotliCompressionProviderOptions>(
    o => o.Level = System.IO.Compression.CompressionLevel.Optimal);
builder.Services.Configure<Microsoft.AspNetCore.ResponseCompression.GzipCompressionProviderOptions>(
    o => o.Level = System.IO.Compression.CompressionLevel.Optimal);
builder.Services.Configure<FormOptions>(o => o.MultipartBodyLengthLimit = maxBody);

// Behind IIS or nginx the visitor's address arrives in X-Forwarded-For. Only a proxy on this
// machine or one listed in KnownProxies is believed, so a visitor cannot pick their own address.
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    foreach (string proxy in xpact.KnownProxies) o.KnownProxies.Add(IPAddress.Parse(proxy));
});

// HSTS: browsers that saw the site over HTTPS keep using HTTPS for a year. Sent only on HTTPS
// requests outside Development; behind a proxy, X-Forwarded-Proto tells the API the visitor used HTTPS.
builder.Services.AddHsts(o => o.MaxAge = TimeSpan.FromDays(365));
builder.Services.AddSingleton<IWorkerLimiter, JobObjectWorkerLimiter>();
builder.Services.AddSingleton<IWorkerRunner, WorkerRunner>();
builder.Services.AddProblemDetails();
builder.Services.AddCors(o => o.AddPolicy("dev", p => p.WithOrigins("http://localhost:5173").AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy("validate", context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = Math.Max(1, xpact.RequestsPerMinute),
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0,
        }));
});

var app = builder.Build();

app.UseForwardedHeaders();
if (!app.Environment.IsDevelopment()) app.UseHsts();
app.UseExceptionHandler();
app.Use(async (context, next) =>
{
    var headers = context.Response.Headers;
    headers["X-Content-Type-Options"] = "nosniff";
    headers["Referrer-Policy"] = "no-referrer";
    headers["X-Frame-Options"] = "DENY";
    // React sets style props through the DOM (element.style), which CSP allows, so inline styles need no
    // 'unsafe-inline'. base-uri, form-action and object-src do not fall back to default-src: set them too.
    headers["Content-Security-Policy"] =
        "default-src 'self'; img-src 'self' data:; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; " +
        "base-uri 'self'; form-action 'self'; object-src 'none'";
    headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=(), payment=(), usb=()";
    headers["Cross-Origin-Opener-Policy"] = "same-origin";
    headers["Cross-Origin-Resource-Policy"] = "same-origin";
    await next();
});
if (app.Environment.IsDevelopment()) app.UseCors("dev");
app.UseRateLimiter();
app.UseResponseCompression();
app.UseDefaultFiles();
app.UseStaticFiles(SiteFiles.Options);

var api = app.MapGroup("/api");

api.MapGet("/health", () => Results.Ok(new { status = "ok" }));

api.MapGet("/info", (IOptions<XpactOptions> options) =>
{
    var o = options.Value;
    return Results.Ok(new
    {
        parser = "XPact",
        builds = o.Builds.Select(b => new
        {
            name = b.Key,
            available = File.Exists(XpactOptions.Resolve(b.Value)),
        }),
        limits = new
        {
            maxDocumentBytes = o.MaxDocumentBytes,
            timeoutSeconds = o.TimeoutSeconds,
            workerMemoryMb = o.WorkerMemoryMb,
            requestsPerMinute = o.RequestsPerMinute,
            maxEvents = o.MaxEvents,
        },
    });
});

api.MapPost("/validate", async (HttpRequest http, IWorkerRunner runner, IOptions<XpactOptions> options,
    ILogger<Program> log, CancellationToken cancellationToken) =>
{
    var o = options.Value;
    ValidateInput input;
    try
    {
        input = await ValidateInput.ReadAsync(http, cancellationToken);
    }
    catch (Exception e) when (e is Microsoft.AspNetCore.Http.BadHttpRequestException or InvalidDataException or JsonException)
    {
        // The exception text stays in the log; the visitor gets a fixed message.
        log.LogInformation("Unreadable request: {Error}", e.Message);
        return Problem(StatusCodes.Status400BadRequest, "Unreadable request",
            "The request could not be read. Send JSON, a form with a 'file' or 'xml' field, or the raw XML.");
    }

    if (input.Document is null)
        return Problem(StatusCodes.Status400BadRequest, "No document",
            "Send the XML as a file (field 'file'), as text (field or property 'xml'), or as the raw request body.");
    if (input.Document.Length > o.MaxDocumentBytes)
        return Problem(StatusCodes.Status413PayloadTooLarge, "Document too large",
            $"The limit is {o.MaxDocumentBytes:N0} bytes; this document has {input.Document.Length:N0}.");

    string build = string.IsNullOrWhiteSpace(input.Build) ? runner.Builds.First() : input.Build.Trim().ToLowerInvariant();
    if (!runner.Builds.Contains(build))
        return Problem(StatusCodes.Status400BadRequest, "Unknown build",
            $"Use one of: {string.Join(", ", runner.Builds)}.");

    int chunk = input.ChunkSize ?? 0;
    if (chunk < 0 || (chunk > 0 && chunk < o.MinChunkSize))
        return Problem(StatusCodes.Status400BadRequest, "Bad chunk size",
            $"Use 0 for the whole document, or a size of at least {o.MinChunkSize} byte(s).");

    // The same address the rate limiter uses (X-Forwarded-For only from trusted proxies).
    string client = http.HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
    try
    {
        var result = await runner.RunAsync(new ParseRequest(input.Document, build, chunk, client), cancellationToken);
        return Results.Ok(result);
    }
    catch (WorkerBusyException busy)
    {
        http.HttpContext.Response.Headers.RetryAfter = busy.RetryAfterSeconds.ToString();
        return Problem(busy.StatusCode, busy.Title, busy.Message);
    }
}).RequireRateLimiting("validate").DisableAntiforgery();

// Conformance and benchmark numbers, exported from the repository's reports by scripts/export-data.py.
string[] dataFiles = { "conformance", "benchmarks", "comparison", "testing" };
api.MapGet("/results/{name}", (string name, IOptions<XpactOptions> options) =>
{
    if (!dataFiles.Contains(name)) return Results.NotFound();
    string path = Path.Combine(XpactOptions.Resolve(options.Value.DataDirectory), name + ".json");
    return File.Exists(path)
        ? Results.File(path, "application/json")
        : Problem(StatusCodes.Status404NotFound, "No data", $"{name}.json has not been exported yet.");
});

// The React site, when it has been built into wwwroot (scripts/publish.ps1).
if (File.Exists(Path.Combine(app.Environment.WebRootPath ?? "wwwroot", "index.html")))
    app.MapFallbackToFile("index.html", SiteFiles.Options);

app.Run();

static IResult Problem(int status, string title, string detail) =>
    Results.Problem(statusCode: status, title: title, detail: detail);

/// <summary>Browser caching for the React site.</summary>
internal static class SiteFiles
{
    /// <summary>
    /// Files under /assets/ have a content hash in their name (Vite), so a new build gets new names:
    /// browsers may keep them for a year. Everything else (index.html, favicon, robots.txt) is checked
    /// on every visit, so a new release shows up at once.
    /// </summary>
    public static readonly StaticFileOptions Options = new()
    {
        OnPrepareResponse = context =>
        {
            context.Context.Response.Headers.CacheControl =
                context.Context.Request.Path.StartsWithSegments("/assets")
                    ? "public, max-age=31536000, immutable"
                    : "no-cache";
        },
    };
}

/// <summary>The three accepted request shapes: multipart form, JSON, or a raw XML body.</summary>
internal sealed record ValidateInput(byte[]? Document, string? Build, int? ChunkSize)
{
    public static async Task<ValidateInput> ReadAsync(HttpRequest http, CancellationToken cancellationToken)
    {
        string? build = http.Query["build"];
        int? chunk = int.TryParse(http.Query["chunkSize"], out int q) ? q : null;

        if (http.HasFormContentType)
        {
            var form = await http.ReadFormAsync(cancellationToken);
            build = form["build"].FirstOrDefault() ?? build;
            if (int.TryParse(form["chunkSize"].FirstOrDefault(), out int f)) chunk = f;
            if (form.Files.GetFile("file") is { } file)
            {
                using var buffer = new MemoryStream();
                await file.CopyToAsync(buffer, cancellationToken);
                return new ValidateInput(buffer.ToArray(), build, chunk);
            }
            string? text = form["xml"].FirstOrDefault();
            return new ValidateInput(text is null ? null : Encoding.UTF8.GetBytes(text), build, chunk);
        }

        if (http.HasJsonContentType())
        {
            var body = await http.ReadFromJsonAsync<JsonBody>(cancellationToken);
            return new ValidateInput(body?.Xml is null ? null : Encoding.UTF8.GetBytes(body.Xml),
                body?.Build ?? build, body?.ChunkSize ?? chunk);
        }

        // Raw body (for example curl --data-binary @file.xml -H "Content-Type: application/xml").
        using var raw = new MemoryStream();
        await http.Body.CopyToAsync(raw, cancellationToken);
        return new ValidateInput(raw.Length == 0 ? null : raw.ToArray(), build, chunk);
    }

    private sealed record JsonBody(string? Xml, string? Build, int? ChunkSize);
}

/// <summary>Lets the integration tests start the API in memory.</summary>
public partial class Program;
