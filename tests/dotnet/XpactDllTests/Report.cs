using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace XpactDllTests;

/// <summary>The judged result of one case. Kind: PASS, FAIL, CRASH or TIMEOUT.</summary>
internal sealed class Row
{
    public required TestCase Case { get; init; }
    public required string Kind { get; init; }
    public RunOutcome? Outcome { get; init; }
    public string Problem { get; init; } = "";
    /// <summary>How the result was obtained, when not in the normal way (e.g. a retry).</summary>
    public string Note { get; set; } = "";

    public static Row Crash(TestCase t, int exitCode, string output) => new()
    {
        Case = t,
        Kind = "CRASH",
        Problem = CrashReason(exitCode, output),
    };

    public static Row Timeout(TestCase t, int seconds) => new()
    {
        Case = t,
        Kind = "TIMEOUT",
        Problem = $"no result after {seconds} s (killed)",
    };

    /// <summary>The first routine and message of an Eiffel exception trace, or the exit code.</summary>
    private static string CrashReason(int exitCode, string output)
    {
        string exit = $"exit {exitCode} (0x{unchecked((uint)exitCode):X8})";
        var lines = output.Split('\n').Select(l => l.TrimEnd('\r')).ToList();
        // The first entry of an Eiffel exception trace (class, routine, tag, nature) runs
        // from the line after the dashes below the header to the next line of dashes.
        int header = lines.FindIndex(l => l.StartsWith("Class / Object"));
        if (header >= 0)
        {
            var entry = lines.Skip(header + 2).TakeWhile(l => !l.StartsWith("-----"));
            string text = Regex.Replace(string.Join(" ", entry), "<[0-9A-Fa-f]+>", "");
            text = Regex.Replace(text, @"\s(Fail|Exit|Bye)\s*$", "");
            text = Regex.Replace(text, @"\s+", " ").Trim();
            if (text.Length > 0) return $"{text}, {exit}";
        }
        string? first = lines.FirstOrDefault(l => l.Trim().Length > 0);
        return first == null ? exit : $"{exit}: {first.Trim()}";
    }
}

internal static class Evaluator
{
    public static Row Evaluate(TestCase t, RunOutcome r)
    {
        string expected = t.Input.Expect == Expect.Accept ? "ACCEPT" : "REJECT";
        if (r.Verdict != expected)
        {
            string got = r.Verdict == "REJECT" ? $"REJECT ({r.ErrorCode} {r.ErrorString})" : r.Verdict;
            return new Row { Case = t, Kind = "FAIL", Outcome = r, Problem = $"expected {expected}, got {got}" };
        }
        if (t.Input.Expect == Expect.Accept)
        {
            Cb flags = t.Callbacks.Flags;
            if (t.Input.Elements != null)
            {
                var want = t.Input.Elements.Where(e =>
                    (e.StartsWith("start:") && flags.HasFlag(Cb.Start)) ||
                    (e.StartsWith("end:") && flags.HasFlag(Cb.End))).ToList();
                var got = r.Events.Where(e => e.StartsWith("start:") || e.StartsWith("end:")).ToList();
                if (!want.SequenceEqual(got))
                {
                    return new Row
                    {
                        Case = t, Kind = "FAIL", Outcome = r,
                        Problem = $"element events: expected [{string.Join(", ", want)}], got [{string.Join(", ", got)}]",
                    };
                }
            }
            if (t.Input.Text != null && flags.HasFlag(Cb.Text))
            {
                // The API may split character data over several callbacks, so compare the joined text.
                string got = string.Concat(r.Events.Where(e => e.StartsWith("text:")).Select(e => e[5..]));
                if (got != t.Input.Text)
                {
                    return new Row
                    {
                        Case = t, Kind = "FAIL", Outcome = r,
                        Problem = $"character data: expected \"{t.Input.Text}\", got \"{got}\"",
                    };
                }
            }
        }
        return new Row { Case = t, Kind = "PASS", Outcome = r };
    }
}

internal static class Report
{
    public static string VerboseLine(Row r)
    {
        var o = r.Outcome;
        string result = o == null ? r.Kind
            : o.Verdict == "REJECT" ? $"REJECT {o.ErrorCode} at {o.Line}:{o.Column} (call {o.FailedCall}/{o.CallCount})"
            : o.Verdict;
        string events = o == null ? "" : string.Join(" | ", o.Events);
        string problem = r.Problem.Length > 0 ? $"  <- {r.Problem}" : "";
        return $"{r.Kind,-7} {r.Case.Id,-45} {result}  [{events}]{problem}";
    }

    public static string Summary(Options opt, List<Row> rows, string version, int children, TimeSpan elapsed)
    {
        var sb = new StringBuilder();
        sb.AppendLine("xpact DLL tests (tests/dotnet/XpactDllTests)");
        sb.AppendLine($"Date:      {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
        sb.AppendLine($"Commit:    {GitCommit()}");
        sb.AppendLine($"DLL:       {opt.DllPath}");
        var info = new FileInfo(opt.DllPath);
        sb.AppendLine($"           {info.Length:N0} bytes, modified {info.LastWriteTime:yyyy-MM-dd HH:mm}, SHA-256 {Sha256(opt.DllPath)}");
        sb.AppendLine($"Version:   {version}");
        sb.AppendLine($"Filters:   {(opt.FilterArgs.Count == 0 ? "none" : string.Join(" ", opt.FilterArgs))}{(opt.Isolate ? ", --isolate" : "")}, --jobs {opt.Jobs}");
        sb.AppendLine($"Run:       {rows.Count} cases in {children} process(es), {elapsed.TotalSeconds:F1} s");
        sb.AppendLine();
        sb.AppendLine($"TOTAL  {rows.Count}   pass {Count(rows, "PASS")}   fail {Count(rows, "FAIL")}   crash {Count(rows, "CRASH")}   timeout {Count(rows, "TIMEOUT")}");
        var retried = rows.Where(r => r.Note.Length > 0).ToList();
        if (retried.Count > 0)
        {
            sb.AppendLine($"       {retried.Count} case(s) gave TIMEOUT in the full run and were retried alone; the table shows the retry:");
            foreach (var r in retried) sb.AppendLine($"         {r.Case.Id,-50} -> {r.Kind}");
        }
        sb.AppendLine();

        sb.AppendLine("1. BY GROUP AND CHUNKING");
        sb.AppendLine($"   {"group",-6} {"chunks",-6} {"total",6} {"pass",6} {"fail",6} {"crash",6} {"timeout",8}");
        foreach (var g in rows.GroupBy(r => (r.Case.Input.Group, r.Case.ChunkKind)))
        {
            var l = g.ToList();
            sb.AppendLine($"   {g.Key.Group,-6} {g.Key.ChunkKind,-6} {l.Count,6} {Count(l, "PASS"),6} {Count(l, "FAIL"),6} {Count(l, "CRASH"),6} {Count(l, "TIMEOUT"),8}");
        }
        sb.AppendLine();

        // One line per input: the whole-document result for each callback set,
        // then how many of its chunked runs went wrong.
        var cbNames = rows.Select(r => r.Case.Callbacks.Name).Distinct().ToList();
        sb.AppendLine("2. BY INPUT  (whole document per callback set: ok, or what went wrong; then chunked runs not ok)");
        sb.Append($"   {"input",-34} {"expect",-7}");
        foreach (string cb in cbNames) sb.Append($" {cb,-10}");
        sb.AppendLine(" chunked");
        foreach (var g in rows.GroupBy(r => r.Case.Input.Name))
        {
            var input = g.First().Case.Input;
            sb.Append($"   {input.Name,-34} {input.Expect.ToString().ToUpperInvariant(),-7}");
            foreach (string cb in cbNames)
            {
                var whole = g.FirstOrDefault(r => r.Case.Callbacks.Name == cb && r.Case.ChunkKind == "whole");
                sb.Append($" {Cell(whole),-10}");
            }
            var chunked = g.Where(r => r.Case.ChunkKind != "whole").ToList();
            sb.AppendLine(chunked.Count == 0 ? " -" : $" {chunked.Count(r => r.Kind != "PASS")}/{chunked.Count}");
        }
        sb.AppendLine("   Cells: ok = right result. ACCEPT!/REJECT! = wrong verdict. EVENTS! = right verdict, wrong events.");
        sb.AppendLine();

        var crashes = rows.Where(r => r.Kind == "CRASH").ToList();
        if (crashes.Count > 0)
        {
            sb.AppendLine("3. CRASH REASONS  (full output in crashes\\<case number>.txt)");
            foreach (var g in crashes.GroupBy(r => Regex.Replace(r.Problem, "@[0-9]+", "@n")).OrderByDescending(g => g.Count()))
            {
                sb.AppendLine($"   {g.Count(),5} x  {g.First().Problem}");
                sb.AppendLine($"           e.g. {string.Join(", ", g.Take(3).Select(r => r.Case.Id))}");
            }
            sb.AppendLine();
        }

        // C03: a chunked run should give the same answer as the whole document.
        sb.AppendLine("4. CHUNKED RUNS THAT DIFFER FROM THE WHOLE DOCUMENT  (same input and callbacks; verdict or error code)");
        var differ = new List<string>();
        foreach (var g in rows.GroupBy(r => (r.Case.Input.Name, r.Case.Callbacks.Name)))
        {
            var whole = g.FirstOrDefault(r => r.Case.ChunkKind == "whole");
            if (whole == null) continue;
            foreach (var r in g.Where(r => r.Case.ChunkKind != "whole"))
            {
                if (Short(r) != Short(whole)) differ.Add($"   {r.Case.Id,-50} whole: {Short(whole),-14} this: {Short(r)}");
            }
        }
        sb.AppendLine($"   {differ.Count} run(s)");
        foreach (string d in differ.Take(25)) sb.AppendLine(d);
        if (differ.Count > 25) sb.AppendLine($"   ... {differ.Count - 25} more in results.tsv");
        sb.AppendLine();

        // Not judged: the reference codes come from libexpat's documented behaviour, check them in G03.
        sb.AppendLine("5. ERROR CODES OF REJECTED DOCUMENTS  (information only; libexpat reference to confirm in G03)");
        foreach (var g in rows.Where(r => r.Case.Input.Expect == Expect.Reject && r.Outcome?.Verdict == "REJECT")
                              .GroupBy(r => r.Case.Input.Name))
        {
            string codes = string.Join(", ", g.GroupBy(r => r.Outcome!.ErrorCode).OrderBy(c => c.Key)
                .Select(c => $"{c.Key} {c.First().Outcome!.ErrorString} ({c.Count()}x)"));
            sb.AppendLine($"   {g.Key,-34} libexpat {g.First().Case.Input.ExpatError,-3} xpact: {codes}");
        }
        sb.AppendLine();

        var fails = rows.Where(r => r.Kind == "FAIL").ToList();
        sb.AppendLine($"6. FAILURES  ({fails.Count}; first 30)");
        foreach (var r in fails.Take(30)) sb.AppendLine($"   {r.Case.Id,-50} {r.Problem}");
        return sb.ToString();
    }

    public static void WriteTsv(string path, List<Row> rows)
    {
        var sb = new StringBuilder();
        sb.AppendLine(string.Join('\t', "index", "id", "group", "input", "callbacks", "chunks", "input_bytes",
            "expected", "result", "verdict", "error_code", "error_string", "libexpat_code", "line", "column",
            "byte_index", "failed_call", "calls", "events", "problem", "note"));
        foreach (var r in rows)
        {
            var t = r.Case;
            var o = r.Outcome;
            sb.AppendLine(string.Join('\t',
                t.Index, t.Id, t.Input.Group, t.Input.Name, t.Callbacks.Name, t.Chunking, Bytes.Escape(t.Input.Bytes),
                t.Input.Expect.ToString().ToUpperInvariant(), r.Kind, o?.Verdict ?? "", o?.ErrorCode.ToString() ?? "",
                Clean(o?.ErrorString ?? ""), t.Input.ExpatError, o?.Line.ToString() ?? "", o?.Column.ToString() ?? "",
                o?.ByteIndex.ToString() ?? "", o?.FailedCall.ToString() ?? "", t.Calls.Count,
                o == null ? "" : string.Join(" | ", o.Events), Clean(r.Problem), Clean(r.Note)));
        }
        File.WriteAllText(path, sb.ToString());
    }

    private static string Cell(Row? r) => r == null ? "-" : r.Kind switch
    {
        "PASS" => "ok",
        "FAIL" when r.Outcome?.Verdict is "ACCEPT" or "REJECT" && r.Problem.StartsWith("expected") => r.Outcome.Verdict + "!",
        "FAIL" when r.Outcome?.Verdict is "ACCEPT" or "REJECT" => "EVENTS!",
        "FAIL" => r.Outcome?.Verdict ?? "FAIL",
        _ => r.Kind,
    };

    private static string Short(Row r) => r.Outcome == null ? r.Kind
        : r.Outcome.Verdict == "REJECT" ? $"REJECT {r.Outcome.ErrorCode}" : r.Outcome.Verdict;

    private static int Count(IEnumerable<Row> rows, string kind) => rows.Count(r => r.Kind == kind);

    private static string Clean(string s) => s.Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');

    private static string Sha256(string path)
    {
        using var stream = File.OpenRead(path);
        return Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
    }

    private static string GitCommit()
    {
        try
        {
            var psi = new ProcessStartInfo("git", "rev-parse HEAD")
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                WorkingDirectory = Options.RepoRoot(),
            };
            using var p = Process.Start(psi)!;
            string head = p.StandardOutput.ReadToEnd().Trim();
            p.WaitForExit();
            var status = new ProcessStartInfo("git", "status --porcelain --untracked-files=no -- src native include tests")
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                WorkingDirectory = Options.RepoRoot(),
            };
            using var s = Process.Start(status)!;
            bool dirty = s.StandardOutput.ReadToEnd().Trim().Length > 0;
            s.WaitForExit();
            return dirty ? $"{head} (uncommitted changes in src/native/include/tests)" : head;
        }
        catch
        {
            return "unknown (git not found)";
        }
    }
}
