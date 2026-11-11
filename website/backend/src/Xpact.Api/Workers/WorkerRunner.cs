using System.Diagnostics;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Xpact.Contracts;

namespace Xpact.Api.Workers;

/// <summary>What the caller asks the worker to do.</summary>
public sealed record ParseRequest(byte[] Document, string Build, int ChunkSize);

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

    public WorkerRunner(IOptions<XpactOptions> options, ILogger<WorkerRunner> log)
    {
        _options = options.Value;
        _log = log;
        _slots = new SemaphoreSlim(Math.Max(1, _options.MaxConcurrentWorkers));
    }

    public IReadOnlyCollection<string> Builds => _options.Builds.Keys;

    public async Task<ValidationResult> RunAsync(ParseRequest request, CancellationToken cancellationToken)
    {
        string dll = XpactOptions.Resolve(_options.Builds[request.Build]);
        string worker = XpactOptions.Resolve(_options.WorkerPath);
        var clock = Stopwatch.StartNew();

        await _slots.WaitAsync(cancellationToken);
        try
        {
            ValidationResult result = await RunWorkerAsync(worker, dll, request, cancellationToken);
            result.TotalMs = Math.Round(clock.Elapsed.TotalMilliseconds, 3);
            _log.LogInformation("Parsed {Bytes} bytes with {Build}: {Verdict} in {Ms} ms",
                request.Document.Length, request.Build, result.Verdict, result.TotalMs);
            return result;
        }
        finally
        {
            _slots.Release();
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

        var start = new ProcessStartInfo(worker)
        {
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            // An empty working folder: the worker never needs to see the server's files.
            WorkingDirectory = Path.GetTempPath(),
        };
        LimitEnvironment(start.Environment);
        foreach (string arg in new[] { "--dll", dll, "--build", request.Build,
                     "--chunk", request.ChunkSize.ToString(), "--max-events", _options.MaxEvents.ToString() })
            start.ArgumentList.Add(arg);

        using var job = new JobObject((long)_options.WorkerMemoryMb * 1024 * 1024);
        using var process = new Process { StartInfo = start };
        process.Start();
        try
        {
            job.Assign(process);
            process.PriorityClass = ProcessPriorityClass.BelowNormal;
        }
        catch (Exception e)
        {
            _log.LogWarning(e, "Could not limit the worker process");
        }

        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(_options.TimeoutSeconds));
        try
        {
            Task<string> stdout = process.StandardOutput.ReadToEndAsync(timeout.Token);
            Task<string> stderr = process.StandardError.ReadToEndAsync(timeout.Token);
            await process.StandardInput.BaseStream.WriteAsync(request.Document, timeout.Token);
            process.StandardInput.Close();
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
        catch (InvalidOperationException) { }
    }

    private static string Trim(string s) => s.Length <= 300 ? s.Trim() : s[..300].Trim() + "…";

    public void Dispose() => _slots.Dispose();
}
