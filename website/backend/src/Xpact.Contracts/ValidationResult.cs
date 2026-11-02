namespace Xpact.Contracts;

/// <summary>
/// What XPact did with one document. The worker prints it as one JSON line;
/// the API adds timing and returns it to the browser unchanged.
/// </summary>
public sealed class ValidationResult
{
    /// <summary>Always "XPact".</summary>
    public string Parser { get; set; } = "XPact";

    /// <summary>The version string the DLL reports (XML_ExpatVersion).</summary>
    public string Version { get; set; } = "";

    /// <summary>"production" (assertions discarded) or "assertions" (contracts checked).</summary>
    public string Build { get; set; } = "";

    /// <summary>accepted, rejected, crashed, timeout or error (see <see cref="Verdicts"/>).</summary>
    public string Verdict { get; set; } = "";

    /// <summary>True only when the verdict is accepted.</summary>
    public bool WellFormed { get; set; }

    /// <summary>Time spent inside XML_Parse calls, measured by the worker.</summary>
    public double ParseMs { get; set; }

    /// <summary>Wall time for the whole request, measured by the API (includes process start).</summary>
    public double TotalMs { get; set; }

    public int InputBytes { get; set; }

    /// <summary>"whole" (one final XML_Parse call) or "chunks" (see <see cref="ChunkSize"/>).</summary>
    public string Mode { get; set; } = "whole";

    public int ChunkSize { get; set; }

    public int ParseCalls { get; set; }

    public ParseError? Error { get; set; }

    public EventSummary Events { get; set; } = new();

    /// <summary>Set for crashed, timeout and error verdicts: what the API saw.</summary>
    public string? Diagnostic { get; set; }
}

public sealed class ParseError
{
    /// <summary>Expat-compatible error code (XML_GetErrorCode).</summary>
    public int Code { get; set; }

    /// <summary>Text for the code (XML_ErrorString).</summary>
    public string Message { get; set; } = "";

    /// <summary>1-based line (XML_GetCurrentLineNumber).</summary>
    public uint Line { get; set; }

    /// <summary>0-based column, as Expat reports it (XML_GetCurrentColumnNumber).</summary>
    public uint Column { get; set; }

    public int ByteIndex { get; set; }
}

public sealed class EventSummary
{
    public int StartElements { get; set; }
    public int EndElements { get; set; }
    public int TextChunks { get; set; }
    public int Comments { get; set; }
    public int ProcessingInstructions { get; set; }

    /// <summary>The first events in document order, for display.</summary>
    public List<ParseEvent> Sample { get; set; } = new();

    /// <summary>True when more events happened than <see cref="Sample"/> holds.</summary>
    public bool Truncated { get; set; }
}

public sealed class ParseEvent
{
    /// <summary>start, end, text, comment or pi.</summary>
    public string Kind { get; set; } = "";

    /// <summary>Element name, PI target; empty for text and comments.</summary>
    public string Name { get; set; } = "";

    /// <summary>Text, comment or PI data (shortened); attributes as name="value" for start.</summary>
    public string Value { get; set; } = "";

    public uint Line { get; set; }
}

public static class Verdicts
{
    public const string Accepted = "accepted";
    public const string Rejected = "rejected";
    public const string Crashed = "crashed";
    public const string Timeout = "timeout";
    public const string Error = "error";
}
