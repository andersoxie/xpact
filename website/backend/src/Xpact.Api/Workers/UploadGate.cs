using Microsoft.Extensions.Options;

namespace Xpact.Api.Workers;

/// <summary>
/// Admission for /api/validate, checked BEFORE the request body is read (#357). Without it every
/// request was read into memory first and only then refused by the worker limits: 30 parallel
/// 20 MB uploads from one address took the API to 1.7 GB.
/// <list type="bullet">
/// <item>Per visitor: at most <see cref="XpactOptions.MaxWorkersPerClient"/> uploads in flight (429).</item>
/// <item>Whole server: the bodies being held stay within <see cref="XpactOptions.MaxBufferedMb"/> (503).</item>
/// </list>
/// </summary>
public sealed class UploadGate(IOptions<XpactOptions> options, ILogger<UploadGate> log)
{
    /// <summary>Memory one request body costs while it is read and parsed (body, document, copies).</summary>
    public const int CopiesPerByte = 4;

    private readonly XpactOptions _options = options.Value;

    /// <summary>
    /// Admit one upload: null and a lease to dispose when done, or the refusal to return
    /// (413 body too large, 429 this visitor already has enough uploads in flight, 503 memory budget full).
    /// </summary>
    public IResult? Admit(HttpRequest http, string client, long maxBody, out Lease? lease)
    {
        lease = null;
        if (http.ContentLength > maxBody)
            return Results.Problem(statusCode: StatusCodes.Status413PayloadTooLarge, title: "Request too large",
                detail: $"The limit is {_options.MaxDocumentBytes:N0} bytes per document.");
        if (TryEnter(client, Estimate(http.ContentLength, maxBody), out lease, out int status)) return null;

        http.HttpContext.Response.Headers.RetryAfter = "5";
        if (log.IsEnabled(LogLevel.Information))
            log.LogInformation("Upload from {Client} refused before reading ({Status})", client, status);
        return status == StatusCodes.Status429TooManyRequests
            ? Results.Problem(statusCode: status, title: "Too many documents at once",
                detail: $"You already have {_options.MaxWorkersPerClient} document(s) being checked. Wait until they finish.")
            : Results.Problem(statusCode: status, title: "Server busy",
                detail: "The server is busy with other documents. Please try again in a moment.");
    }
    private readonly Dictionary<string, int> _perClient = new();
    private long _bufferedBytes;

    /// <summary>Bytes reserved for a body of <paramref name="contentLength"/> bytes (the largest allowed body when unknown).</summary>
    public static long Estimate(long? contentLength, long maxBody) =>
        Math.Min(contentLength ?? maxBody, maxBody) * CopiesPerByte;

    /// <summary>Reserve room for one upload, or say why not (status 429 or 503).</summary>
    public bool TryEnter(string client, long bytes, out Lease? lease, out int status)
    {
        lease = null;
        lock (_perClient)
        {
            _perClient.TryGetValue(client, out int running);
            if (running >= Math.Max(1, _options.MaxWorkersPerClient))
            {
                status = StatusCodes.Status429TooManyRequests;
                return false;
            }
            long budget = (long)Math.Max(1, _options.MaxBufferedMb) * 1024 * 1024;
            if (_bufferedBytes + bytes > budget && _bufferedBytes > 0)
            {
                status = StatusCodes.Status503ServiceUnavailable;
                return false;
            }
            _perClient[client] = running + 1;
            _bufferedBytes += bytes;
        }
        status = StatusCodes.Status200OK;
        lease = new Lease(this, client, bytes);
        return true;
    }

    /// <summary>Bytes currently reserved (for tests and logs).</summary>
    public long BufferedBytes
    {
        get { lock (_perClient) return _bufferedBytes; }
    }

    private void Leave(string client, long bytes)
    {
        lock (_perClient)
        {
            _bufferedBytes -= bytes;
            if (_perClient.TryGetValue(client, out int running) && running > 1) _perClient[client] = running - 1;
            else _perClient.Remove(client);
        }
    }

    /// <summary>Held while one upload is read and parsed; disposing it frees the reservation.</summary>
    public sealed class Lease(UploadGate gate, string client, long bytes) : IDisposable
    {
        private int _disposed;

        public void Dispose()
        {
            if (Interlocked.Exchange(ref _disposed, 1) == 0) gate.Leave(client, bytes);
        }
    }
}
