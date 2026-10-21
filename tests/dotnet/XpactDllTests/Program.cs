using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace XpactDllTests;

/// <summary>
/// The parent process never loads the DLL. It starts a child copy of this program
/// (--child) that runs the cases one after the other and reports each one on stdout:
///   V  version       once, XML_ExpatVersion()
///   S  index         a case starts
///   R  index json    its result
///   DONE
/// If the child dies (Eiffel contract violation, access violation...) after "S" without
/// "R", that case is a CRASH, and a new child continues with the next case.
/// </summary>
internal static class Program
{
    private static int Main(string[] args)
    {
        Options o;
        try
        {
            o = Options.Parse(args);
        }
        catch (Exception e) when (e is ArgumentException or FormatException)
        {
            Console.Error.WriteLine(e.Message);
            Console.Error.WriteLine(Options.Usage);
            return 2;
        }
        if (o.Help)
        {
            Console.WriteLine(Options.Usage);
            return 0;
        }

        List<TestCase> cases = Catalog.Build(o);
        if (o.List)
        {
            foreach (var c in cases) Console.WriteLine(c.Id);
            Console.WriteLine($"{cases.Count} cases");
            return 0;
        }
        return o.Child ? RunChild(o, cases) : RunParent(o, cases);
    }

    private static int RunChild(Options o, List<TestCase> cases)
    {
        Native.Load(o.DllPath);
        Console.WriteLine("V\t" + Native.Version());
        int ran = 0;
        for (int i = o.From; i < cases.Count && ran < o.Count; i += o.Stride, ran++)
        {
            Console.WriteLine("S\t" + i);
            RunOutcome r = Executor.Run(cases[i]);
            Console.WriteLine("R\t" + i + "\t" + JsonSerializer.Serialize(r));
        }
        Console.WriteLine("DONE");
        return 0;
    }

    private static int RunParent(Options o, List<TestCase> cases)
    {
        if (cases.Count == 0)
        {
            Console.Error.WriteLine("No case matches the filters.");
            return 2;
        }
        if (!File.Exists(o.DllPath))
        {
            Console.Error.WriteLine($"DLL not found: {o.DllPath}");
            return 2;
        }
        Directory.CreateDirectory(o.OutDir);

        var rows = new Row?[cases.Count];
        var state = new RunState();
        var clock = Stopwatch.StartNew();

        // Worker w runs cases w, w + jobs, w + 2*jobs, ... in its own chain of child processes,
        // so a slow crash (Windows error reporting takes a few seconds) does not stall the others.
        int jobs = Math.Max(1, Math.Min(o.Jobs, cases.Count));
        string? Worker(int w)
        {
            int next = w;
            while (next < cases.Count)
            {
                var (after, fatal) = RunOneChild(o, cases, rows, next, o.Isolate ? 1 : int.MaxValue, jobs, state);
                Interlocked.Increment(ref state.Children);
                if (fatal != null) return fatal;
                next = after;
            }
            return null;
        }
        var workers = Enumerable.Range(0, jobs).Select(w => Task.Run(() => Worker(w))).ToArray();
        while (!Task.WaitAll(workers, 1000))
        {
            if (!o.Verbose) Console.Error.Write($"\r{rows.Count(r => r != null)}/{cases.Count} cases, {state.Children} process(es)   ");
        }
        if (!o.Verbose) Console.Error.WriteLine($"\r{cases.Count}/{cases.Count} cases, {state.Children} process(es)   ");
        clock.Stop();
        string? firstFatal = workers.Select(t => t.Result).FirstOrDefault(f => f != null);
        if (firstFatal != null)
        {
            Console.Error.WriteLine(firstFatal);
            return 2;
        }
        // A crashed child sometimes needs longer than the timeout to end when several crash
        // at once. Retry each TIMEOUT case once on its own, and keep what that run shows.
        int retried = 0;
        for (int i = 0; i < rows.Length; i++)
        {
            if (rows[i]!.Kind != "TIMEOUT") continue;
            var first = rows[i]!;
            RunOneChild(o, cases, rows, i, 1, 1, state);
            Interlocked.Increment(ref state.Children);
            retried++;
            rows[i]!.Note = $"retried alone after: {first.Problem}";
        }
        if (retried > 0 && !o.Verbose) Console.Error.WriteLine($"{retried} TIMEOUT case(s) retried alone");
        string version = state.Version;
        int children = state.Children;

        var finished = rows.Select(r => r!).ToList();
        if (o.Verbose)
        {
            foreach (var r in finished) Console.WriteLine(Report.VerboseLine(r));
        }
        string summary = Report.Summary(o, finished, version, children, clock.Elapsed);
        Console.WriteLine(summary);
        File.WriteAllText(Path.Combine(o.OutDir, "summary.txt"), summary);
        Report.WriteTsv(Path.Combine(o.OutDir, "results.tsv"), finished);
        Console.WriteLine($"Results: {o.OutDir}");
        return finished.All(r => r.Kind == "PASS") ? 0 : 1;
    }

    private sealed class RunState
    {
        public volatile string Version = "?";
        public int Children;
    }

    /// <summary>
    /// Runs one child for cases from, from + stride, ... (at most <paramref name="count"/>).
    /// Returns the next case this worker has to run.
    /// </summary>
    private static (int Next, string? Fatal) RunOneChild(
        Options o, List<TestCase> cases, Row?[] rows, int from, int count, int stride, RunState state)
    {
        var psi = new ProcessStartInfo(Environment.ProcessPath!)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        foreach (string a in new[] { "--child", "--dll", o.DllPath, "--from", from.ToString(), "--count", count.ToString(), "--stride", stride.ToString() })
            psi.ArgumentList.Add(a);
        foreach (string a in o.FilterArgs) psi.ArgumentList.Add(a);

        using var process = new Process { StartInfo = psi };
        var lines = new BlockingCollection<string?>();
        var stderr = new StringBuilder();
        process.OutputDataReceived += (_, e) => lines.Add(e.Data); // null = end of output
        process.ErrorDataReceived += (_, e) =>
        {
            if (e.Data != null) lock (stderr) stderr.AppendLine(e.Data);
        };
        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        int? current = null;
        int next = from;
        bool done = false;
        var caseClock = new Stopwatch();
        var otherOutput = new StringBuilder();
        while (true)
        {
            if (!lines.TryTake(out string? line, 250))
            {
                if (current is int hung && caseClock.Elapsed.TotalSeconds > o.TimeoutSeconds)
                {
                    try { process.Kill(entireProcessTree: true); } catch { }
                    process.WaitForExit();
                    rows[hung] = Row.Timeout(cases[hung], o.TimeoutSeconds);
                    return (hung + stride, null);
                }
                continue;
            }
            if (line == null) break;
            if (line.StartsWith("V\t"))
            {
                state.Version = line[2..];
            }
            else if (line.StartsWith("S\t"))
            {
                // stderr is not cleared here: it arrives on another pipe, so lines of
                // this case could already be in it. A child stops at its first crash,
                // so whatever it wrote to stderr belongs to that crash.
                current = int.Parse(line[2..]);
                caseClock.Restart();
                otherOutput.Clear();
            }
            else if (line.StartsWith("R\t"))
            {
                string[] parts = line.Split('\t', 3);
                int i = int.Parse(parts[1]);
                RunOutcome outcome = JsonSerializer.Deserialize<RunOutcome>(parts[2])!;
                rows[i] = Evaluator.Evaluate(cases[i], outcome);
                current = null;
                next = i + stride;
            }
            else if (line == "DONE")
            {
                done = true;
            }
            else
            {
                otherOutput.AppendLine(line); // the DLL wrote to stdout
            }
        }
        process.WaitForExit();
        string errText;
        lock (stderr) errText = stderr.ToString();

        if (current is int crashed)
        {
            string output = errText + otherOutput;
            rows[crashed] = Row.Crash(cases[crashed], process.ExitCode, output);
            string dir = Path.Combine(o.OutDir, "crashes");
            Directory.CreateDirectory(dir);
            File.WriteAllText(Path.Combine(dir, $"{crashed:D4}.txt"),
                $"case: {cases[crashed].Id}\ninput: {Bytes.Escape(cases[crashed].Input.Bytes)}\n" +
                $"exit code: {process.ExitCode} (0x{unchecked((uint)process.ExitCode):X8})\n\n{output}");
            return (crashed + stride, null);
        }
        if (!done && next == from)
        {
            return (next, $"The child process stopped before running a case (exit {process.ExitCode}).\n{errText}");
        }
        return (next, null);
    }
}
