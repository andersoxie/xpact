using System.Text.Json;
using Microsoft.Extensions.Options;
using Xpact.Api.Workers;

namespace Xpact.Api;

/// <summary>The /api endpoints.</summary>
internal static class ApiEndpoints
{
    // Conformance and benchmark numbers, exported from the repository's reports by scripts/export-data.py.
    private static readonly string[] DataFiles = ["conformance", "benchmarks", "comparison", "testing"];

    public static void Map(WebApplication app, XpactOptions xpact, long maxBody)
    {
        var api = app.MapGroup("/api");
        api.MapGet("/health", () => Results.Ok(new { status = "ok" }));
        api.MapGet("/info", Info);
        api.MapPost("/validate", (HttpRequest http, IWorkerRunner runner, UploadGate gate, IOptions<XpactOptions> options,
                ILogger<Program> log, CancellationToken cancellationToken) =>
                ValidateAsync(http, runner, gate, options.Value, log, maxBody, cancellationToken))
            .RequireRateLimiting("validate").DisableAntiforgery()
            // #358: upload + queue + parse together; then the request is cancelled (504) and its memory freed.
            .WithRequestTimeout(TimeSpan.FromSeconds(Math.Max(1, xpact.RequestTimeoutSeconds)));
        api.MapGet("/results/{name}", Result);
    }

    private static IResult Info(IOptions<XpactOptions> options)
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
    }

    private static async Task<IResult> ValidateAsync(HttpRequest http, IWorkerRunner runner, UploadGate gate, XpactOptions o,
        ILogger<Program> log, long maxBody, CancellationToken cancellationToken)
    {
        // The same address the rate limiter uses (X-Forwarded-For only from trusted proxies).
        string client = http.HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";

        // #357: decide BEFORE reading the body, so a refused upload costs no memory.
        if (gate.Admit(http, client, maxBody, out var lease) is { } refusal) return refusal;
        using var _ = lease;

        ValidateInput input;
        try
        {
            input = await ValidateInput.ReadAsync(http, cancellationToken);
        }
        catch (Exception e) when (e is BadHttpRequestException or InvalidDataException or JsonException)
        {
            // The exception stays in the log; the visitor gets a fixed message.
            if (log.IsEnabled(LogLevel.Information))
                log.LogInformation(e, "Unreadable request from {Client}", client);
            return Problem(StatusCodes.Status400BadRequest, "Unreadable request",
                "The request could not be read. Send JSON, a form with a 'file' or 'xml' field, or the raw XML.");
        }

        if (Check(input, runner, o) is { } invalid) return invalid;

        string build = string.IsNullOrWhiteSpace(input.Build) ? runner.Builds.First() : input.Build.Trim().ToLowerInvariant();
        try
        {
            var result = await runner.RunAsync(new ParseRequest(input.Document!, build, input.ChunkSize ?? 0, client), cancellationToken);
            return Results.Ok(result);
        }
        catch (WorkerBusyException busy)
        {
            http.HttpContext.Response.Headers.RetryAfter = busy.RetryAfterSeconds.ToString();
            return Problem(busy.StatusCode, busy.Title, busy.Message);
        }
    }

    /// <summary>The request's document, build and chunk size are usable, or the problem to send back.</summary>
    private static IResult? Check(ValidateInput input, IWorkerRunner runner, XpactOptions o)
    {
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
        return null;
    }

    private static IResult Result(string name, IOptions<XpactOptions> options)
    {
        if (!DataFiles.Contains(name)) return Results.NotFound();
        string path = Path.Combine(XpactOptions.Resolve(options.Value.DataDirectory), name + ".json");
        return File.Exists(path)
            ? Results.File(path, "application/json")
            : Problem(StatusCodes.Status404NotFound, "No data", $"{name}.json has not been exported yet.");
    }

    private static IResult Problem(int status, string title, string detail) =>
        Results.Problem(statusCode: status, title: title, detail: detail);
}
