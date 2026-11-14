using System.Diagnostics;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Xpact.Contracts;

namespace Xpact.Api.Workers;

/// <summary>What the caller asks the worker to do. <paramref name="Client"/> is the visitor's IP (per-client cap).</summary>
public sealed record ParseRequest(byte[] Document, string Build, int ChunkSize, string Client = "unknown");

/// <summary>
/// The request was not run because no worker could be given to it: 429 (this client already uses its
/// share) or 503 (all workers busy, the queue is full or the wait timed out).
/// </summary>
public sealed class WorkerBusyException(int statusCode, string title, string detail, int retryAfterSeconds)
    : Exception(detail)
{
    public int StatusCode { get; } = statusCode;
    public string Title { get; } = title;
    public int RetryAfterSeconds { get; } = retryAfterSeconds;
}

public interface IWorkerRunner
{
    IReadOnlyCollection<string> Builds { get; }
    Task<ValidationResult> RunAsync(ParseRequest request, CancellationToken cancellationToken);
}

/// <summary>
/// Runs one Xpact.Worker process per document: the document goes in on stdin,
/// one JSON line comes back on stdout. The process runs inside a Job Object
/// (memory cap, killed with the job) and is killed after the timeout.
/// </summary>
public sealed class WorkerRunner : IWorkerRunner, IDisposable
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly XpactOptions _options;
    private readonly ILogger<WorkerRunner> _log;
    private readonly SemaphoreSlim _slots;
    private readonly IWorkerLimiter _limiter;
    private readonly IWorkerLauncher _launcher;
    private readonly Dictionary<string, int> _perClient = new();
    private int _waiting;

    public WorkerRunner(IOptions<XpactOptions> options, ILogger<WorkerRunner> log, IWorkerLimiter limiter,
        IWorkerLauncher launcher)
    {
        _options = options.Value;
        _log = log;
        _limiter = limiter;
        _launcher = launcher;
        _slots = new SemaphoreSlim(Math.Max(1, _options.MaxConcurrentWorkers));
    }

    public IReadOnlyCollection<string> Builds => _options.Builds.Keys;

    public async Task<ValidationResult> RunAsync(ParseRequest request, CancellationToken cancellationToken)
    {
        string dll = XpactOptions.Resolve(_options.Builds[request.Build]);
        string worker = XpactOptions.Resolve(_options.WorkerPath);
        var clock = Stopwatch.StartNew();

        if (!TryEnterClient(request.Client))
        {
            if (_log.IsEnabled(LogLevel.Information))
                _log.LogInformation("Client {Client} already uses {Max} worker(s); request refused", request.Client, _options.MaxWorkersPerClient);
            throw new WorkerBusyException(StatusCodes.Status429TooManyRequests, "Too many documents at once",
                $"You already have {_options.MaxWorkersPerClient} document(s) being checked. Wait until they finish.", 5);
        }
        try
        {
            await WaitForSlotAsync(cancellationToken);
            try
            {
                ValidationResult result = await RunWorkerAsync(worker, dll, request, cancellationToken);
                result.TotalMs = Math.Round(clock.Elapsed.TotalMilliseconds, 3);
                if (_log.IsEnabled(LogLevel.Information))
                    _log.LogInformation("Parsed {Bytes} bytes from {Client} with {Build}: {Verdict} in {Ms} ms",
                        request.Document.Length, request.Client, request.Build, result.Verdict, result.TotalMs);
                return result;
            }
            finally
            {
                _slots.Release();
            }
        }
        finally
        {
            LeaveClient(request.Client);
        }
    }

    /// <summary>
    /// Take a worker slot: at once if one is free; otherwise wait in a queue of at most
    /// <see cref="XpactOptions.MaxQueuedRequests"/> for at most <see cref="XpactOptions.QueueWaitSeconds"/>.
    /// </summary>
    private async Task WaitForSlotAsync(CancellationToken cancellationToken)
    {
        if (await _slots.WaitAsync(0, cancellationToken)) return;

        if (Interlocked.Increment(ref _waiting) > Math.Max(0, _options.MaxQueuedRequests))
        {
            Interlocked.Decrement(ref _waiting);
            _log.LogWarning("Worker queue full ({Max} waiting); request refused", _options.MaxQueuedRequests);
            throw Busy("The server is busy: too many documents are waiting. Please try again in a moment.");
        }
        bool entered;
        try
        {
            entered = await _slots.WaitAsync(TimeSpan.FromSeconds(Math.Max(0, _options.QueueWaitSeconds)), cancellationToken);
        }
        finally
        {
            Interlocked.Decrement(ref _waiting);
        }
        if (!entered)
        {
            _log.LogWarning("No worker free within {Seconds} s; request refused", _options.QueueWaitSeconds);
            throw Busy($"The server is busy: no parser was free within {_options.QueueWaitSeconds} s. Please try again in a moment.");
        }
    }

    private WorkerBusyException Busy(string detail) =>
        new(StatusCodes.Status503ServiceUnavailable, "Server busy", detail, Math.Max(1, _options.TimeoutSeconds));

    private bool TryEnterClient(string client)
    {
        lock (_perClient)
        {
            _perClient.TryGetValue(client, out int running);
            if (running >= Math.Max(1, _options.MaxWorkersPerClient)) return false;
            _perClient[client] = running + 1;
            return true;
        }
    }

    private void LeaveClient(string client)
    {
        lock (_perClient)
        {
            if (_perClient.TryGetValue(client, out int running) && running > 1) _perClient[client] = running - 1;
            else _perClient.Remove(client);
        }
    }

    private async Task<ValidationResult> RunWorkerAsync(string worker, string dll, ParseRequest request,
        CancellationToken cancellationToken)
    {
        ValidationResult Failure(string verdict, string diagnostic) => new()
        {
            Build = request.Build,
            Verdict = verdict,
            InputBytes = request.Document.Length,
            Mode = request.ChunkSize > 0 ? "chunks" : "whole",
            ChunkSize = request.ChunkSize,
            Diagnostic = diagnostic,
        };

        if (!File.Exists(worker)) return Failure(Verdicts.Error, "The parser worker is not installed on the server.");
        if (!File.Exists(dll)) return Failure(Verdicts.Error, $"The '{request.Build}' parser build is not installed on the server.");

        var environment = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        foreach (System.Collections.DictionaryEntry e in Environment.GetEnvironmentVariables())
            environment[(string)e.Key] = (string?)e.Value;
        LimitEnvironment(environment);
        string[] arguments = { "--dll", dll, "--build", request.Build,
            "--chunk", request.ChunkSize.ToString(), "--max-events", _options.MaxEvents.ToString() };

        // Started suspended (below-normal priority, Low integrity unless configured off): it runs no code
        // until it is under its memory cap. Fail closed: if it cannot be started that way, nothing is parsed.
        WorkerProcess started;
        try
        {
            // An empty working folder: the worker never needs to see the server's files.
            started = _launcher.Start(worker, arguments, environment, Path.GetTempPath());
        }
        catch (Exception e)
        {
            _log.LogError(e, "Could not start the worker with reduced rights; request refused");
            return Failure(Verdicts.Error, "The server could not start the parser safely, so the document was not parsed. Please try again later.");
        }
        using WorkerProcess owned = started;
        Process process = started.Process;

        IDisposable limit;
        try
        {
            limit = _limiter.Limit(process, (long)_options.WorkerMemoryMb * 1024 * 1024);
        }
        catch (Exception e)
        {
            Kill(process);
            process.WaitForExit(5000);
            _log.LogError(e, "Could not put the worker under its {Mb} MB memory cap; request refused", _options.WorkerMemoryMb);
            return Failure(Verdicts.Error, "The server could not limit the parser process, so the document was not parsed. Please try again later.");
        }
        using var job = limit;
        try
        {
            started.Resume();
        }
        catch (Exception e)
        {
            Kill(process);
            _log.LogError(e, "Could not resume the worker");
            return Failure(Verdicts.Error, "The server could not start the parser safely, so the document was not parsed. Please try again later.");
        }

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(_options.TimeoutSeconds));
        try
        {
            Task<string> stdout = started.StandardOutput.ReadToEndAsync(timeout.Token);
            Task<string> stderr = started.StandardError.ReadToEndAsync(timeout.Token);
            await started.StandardInput.WriteAsync(request.Document, timeout.Token);
            started.StandardInput.Close();
            await process.WaitForExitAsync(timeout.Token);
            string output = await stdout;
            string errors = await stderr;
            // The worker's error output can name server paths or show a stack trace:
            // it goes to the server log only, never to the visitor.
            if (!string.IsNullOrWhiteSpace(errors))
                _log.LogWarning("Worker error output ({Build}): {Errors}", request.Build, Trim(errors));

            if (process.ExitCode != 0 || string.IsNullOrWhiteSpace(output))
            {
                string code = $"0x{process.ExitCode & 0xFFFFFFFF:X8}";
                return Failure(Verdicts.Crashed,
                    $"The parser process stopped with exit code {code} before giving a result.");
            }
            return JsonSerializer.Deserialize<ValidationResult>(output, Json)
                ?? Failure(Verdicts.Error, "The parser returned an empty result.");
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            Kill(process);
            return Failure(Verdicts.Timeout, $"The parser did not finish within {_options.TimeoutSeconds} s and was stopped.");
        }
        catch (IOException e)
        {
            // The worker died while we were still writing the document.
            Kill(process);
            _log.LogWarning(e, "Worker stopped while reading the document");
            return Failure(Verdicts.Crashed, "The parser process stopped while reading the document.");
        }
        finally
        {
            Kill(process);
        }
    }

    /// <summary>
    /// The only environment variables the worker keeps: what Windows and the .NET host need to start a
    /// process. Everything else the API has (connection strings, keys, tokens) is removed, so the
    /// process that parses strangers' XML never sees it.
    /// </summary>
    private static readonly HashSet<string> WorkerEnvironment = new(StringComparer.OrdinalIgnoreCase)
    {
        "SystemRoot", "windir", "SystemDrive", "ComSpec", "PATH", "PATHEXT", "TEMP", "TMP",
        "NUMBER_OF_PROCESSORS", "PROCESSOR_ARCHITECTURE", "ProgramFiles", "ProgramW6432", "ProgramData",
        "USERPROFILE", "LOCALAPPDATA", "APPDATA", "DOTNET_ROOT",
    };

    public static void LimitEnvironment(IDictionary<string, string?> environment)
    {
        foreach (string name in environment.Keys.Where(k => !WorkerEnvironment.Contains(k)).ToList())
            environment.Remove(name);
    }

    private static void Kill(Process process)
    {
        try
        {
            if (!process.HasExited) process.Kill(entireProcessTree: true);
        }
        catch (InvalidOperationException)
        {
            // It ended between the check and the kill: nothing left to stop.
        }
    }

    private static string Trim(string s) => s.Length <= 300 ? s.Trim() : s[..300].Trim() + "…";

    public void Dispose() => _slots.Dispose();
}
