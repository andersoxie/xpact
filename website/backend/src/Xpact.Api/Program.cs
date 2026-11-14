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
    // #358: a client trickling its upload must not hold a connection for hours (Kestrel's default
    // minimum is 240 B/s: a 20 MB body could take 24 h). Together with RequestTimeoutSeconds below.
    o.Limits.MinRequestBodyDataRate = new MinDataRate(bytesPerSecond: 4096, gracePeriod: TimeSpan.FromSeconds(10));
    o.Limits.MaxConcurrentConnections = Math.Max(1, xpact.MaxConnections);
});
builder.Services.AddRequestTimeouts();

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
builder.Services.Configure<FormOptions>(o =>
{
    o.MultipartBodyLengthLimit = maxBody;
    // #359: keep uploaded files in memory. The default (64 KB) spools larger files to a temp file in
    // %TEMP%, so visitors' documents touched the disk. The memory is bounded by UploadGate (#357).
    o.MemoryBufferThreshold = (int)Math.Min(maxBody, int.MaxValue);
});

// Which proxies may set X-Forwarded-For: see SecurityMiddleware.ConfigureForwardedHeaders.
builder.Services.Configure<ForwardedHeadersOptions>(o => SecurityMiddleware.ConfigureForwardedHeaders(o, xpact));

// HSTS: browsers that saw the site over HTTPS keep using HTTPS for a year. Sent only on HTTPS
// requests outside Development; behind a proxy, X-Forwarded-Proto tells the API the visitor used HTTPS.
builder.Services.AddHsts(o => o.MaxAge = TimeSpan.FromDays(365));
builder.Services.AddSingleton<IWorkerLimiter, JobObjectWorkerLimiter>();
builder.Services.AddSingleton<IWorkerLauncher>(sp =>
    new WorkerLauncher(sp.GetRequiredService<IOptions<XpactOptions>>().Value.WorkerLowIntegrity));
builder.Services.AddSingleton<IWorkerRunner, WorkerRunner>();
builder.Services.AddSingleton<UploadGate>();
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
app.UseUntrustedProxyWarning();
if (!app.Environment.IsDevelopment()) app.UseHsts();
app.UseExceptionHandler();
app.UseSecurityHeaders();
if (app.Environment.IsDevelopment()) app.UseCors("dev");
app.UseRateLimiter();
app.UseRequestTimeouts();
app.UseResponseCompression();
app.UseDefaultFiles();
app.UseStaticFiles(SiteFiles.Options);

ApiEndpoints.Map(app, xpact, maxBody);

// The React site, when it has been built into wwwroot (scripts/publish.ps1).
if (File.Exists(Path.Combine(app.Environment.WebRootPath ?? "wwwroot", "index.html")))
    app.MapFallbackToFile("index.html", SiteFiles.Options);

await app.RunAsync();
