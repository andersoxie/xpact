using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;
using Xpact.Contracts;
using Xpact.Worker;

// XPact worker: parses ONE document with xpact.dll and prints one JSON line.
//
//   Xpact.Worker --dll <path> --build <name> [--chunk <bytes>] [--max-events <n>] < document.xml
//
// The API starts one worker per request. A crash inside the DLL (for example a
// failed Eiffel contract) then ends this process only, never the web server.
// The document arrives on stdin as raw bytes, so no file on disk is involved.

var options = WorkerOptions.Parse(args);
if (options is null)
{
    Console.Error.WriteLine("usage: Xpact.Worker --dll <path> --build <name> [--chunk <bytes>] [--max-events <n>]");
    return 2;
}

byte[] input;
using (var stdin = Console.OpenStandardInput())
using (var buffer = new MemoryStream())
{
    stdin.CopyTo(buffer);
    input = buffer.ToArray();
}

ValidationResult result;
try
{
    Native.Load(options.DllPath);
    WarmUp(options);
    result = Parse(input, options);
}
catch (Exception e)
{
    // The details (DLL path, stack trace) go to stderr, which the API writes to its log;
    // the visitor gets a generic message.
    Console.Error.WriteLine(e);
    result = new ValidationResult
    {
        Build = options.Build,
        Verdict = Verdicts.Error,
        InputBytes = input.Length,
        Diagnostic = "The parser could not run on the server (internal error).",
    };
}

Console.Out.WriteLine(JsonSerializer.Serialize(result, WorkerJson.Options));
Console.Out.Flush();
return 0;

// #316: under a small memory cap the parse can use all the memory the Job Object allows. If .NET
// then loads a type or JIT-compiles a method for the first time (JSON output, the error path,
// a finalizer), that fails inside the runtime and the worker dies with "Stack overflow." or an
// access violation instead of reporting code 1. So run every path once now, while memory is free.
static void WarmUp(WorkerOptions options)
{
    foreach (string doc in new[] { "<w a='1'><!--c--><?p d?>t</w>", "<w>" })
    {
        byte[] bytes = System.Text.Encoding.UTF8.GetBytes(doc);
        _ = JsonSerializer.Serialize(Parse(bytes, options with { ChunkSize = 0 }), WorkerJson.Options);
        _ = JsonSerializer.Serialize(Parse(bytes, options with { ChunkSize = 4 }), WorkerJson.Options);
    }
    Console.Out.Flush();
    Console.Error.Flush();
    GC.Collect();
    GC.WaitForPendingFinalizers();
    GC.Collect();
}

static unsafe int Feed(IntPtr parser, byte[] buffer, int length, int chunkSize, ValidationResult result)
{
    fixed (byte* p = buffer)
    {
        if (chunkSize <= 0)
        {
            result.ParseCalls = 1;
            return Native.XML_Parse(parser, p, length, 1);
        }
        // Feed the document in pieces, as a network client would. The verdict
        // must not depend on where the pieces are cut.
        int status = Native.StatusOk;
        int offset = 0;
        bool final = false;
        while (status == Native.StatusOk && !final)
        {
            int piece = Math.Min(chunkSize, length - offset);
            final = offset + piece >= length;
            result.ParseCalls++;
            status = Native.XML_Parse(parser, p + offset, piece, final ? 1 : 0);
            offset += piece;
        }
        return status;
    }
}

static unsafe ValidationResult Parse(byte[] input, WorkerOptions options)
{
    var result = new ValidationResult
    {
        Version = Native.CString(Native.XML_ExpatVersion()),
        Build = options.Build,
        InputBytes = input.Length,
        Mode = options.ChunkSize > 0 ? "chunks" : "whole",
        ChunkSize = options.ChunkSize,
    };

    // No ExternalEntityRefHandler and no parameter-entity parsing are set, so the
    // parser never opens files or URLs named in the document (see docs/security.md).
    IntPtr parser = Native.XML_ParserCreate(null);
    if (parser == IntPtr.Zero)
    {
        result.Verdict = Verdicts.Error;
        result.Diagnostic = "XML_ParserCreate returned NULL";
        return result;
    }

    try
    {
        EventRecorder.Reset(options.MaxEvents);
        EventRecorder.Parser = parser;
        Native.XML_SetStartElementHandler(parser, &EventRecorder.OnStart);
        Native.XML_SetEndElementHandler(parser, &EventRecorder.OnEnd);
        Native.XML_SetCharacterDataHandler(parser, &EventRecorder.OnText);
        Native.XML_SetCommentHandler(parser, &EventRecorder.OnComment);
        Native.XML_SetProcessingInstructionHandler(parser, &EventRecorder.OnPi);

        // One spare byte, so an empty input still has a valid pointer.
        byte[] buffer = new byte[input.Length + 1];
        input.CopyTo(buffer, 0);

        // #316: memory held back from the parser. If the parse uses everything the cap allows,
        // freeing this right after leaves room for .NET to build and print the result.
        const int ReserveBytes = 4 * 1024 * 1024;
        IntPtr reserve = Marshal.AllocHGlobal(ReserveBytes);
        new Span<byte>((void*)reserve, ReserveBytes).Fill(0); // touch every page, so it is really committed
        int status;
        var clock = Stopwatch.StartNew();
        try
        {
            status = Feed(parser, buffer, input.Length, options.ChunkSize, result);
        }
        finally
        {
            Marshal.FreeHGlobal(reserve);
        }
        clock.Stop();
        EventRecorder.Finish();

        result.ParseMs = Math.Round(clock.Elapsed.TotalMilliseconds, 3);
        result.Events = EventRecorder.Summary;
        result.WellFormed = status == Native.StatusOk;
        result.Verdict = result.WellFormed ? Verdicts.Accepted : Verdicts.Rejected;
        if (!result.WellFormed)
        {
            int code = Native.XML_GetErrorCode(parser);
            result.Error = new ParseError
            {
                Code = code,
                Message = Native.CString(Native.XML_ErrorString(code)),
                Line = Native.XML_GetCurrentLineNumber(parser),
                Column = Native.XML_GetCurrentColumnNumber(parser),
                ByteIndex = Native.XML_GetCurrentByteIndex(parser),
            };
        }
        return result;
    }
    finally
    {
        EventRecorder.Parser = IntPtr.Zero;
        Native.XML_ParserFree(parser);
    }
}

internal sealed record WorkerOptions(string DllPath, string Build, int ChunkSize, int MaxEvents)
{
    public static WorkerOptions? Parse(string[] args)
    {
        string? dll = null;
        string build = "production";
        int chunk = 0;
        int maxEvents = 200;
        for (int i = 0; i < args.Length; i++)
        {
            string next = i + 1 < args.Length ? args[i + 1] : "";
            switch (args[i])
            {
                case "--dll": dll = next; i++; break;
                case "--build": build = next; i++; break;
                case "--chunk" when int.TryParse(next, out int c) && c >= 0: chunk = c; i++; break;
                case "--max-events" when int.TryParse(next, out int m) && m >= 0: maxEvents = m; i++; break;
                default: return null;
            }
        }
        return string.IsNullOrEmpty(dll) ? null : new WorkerOptions(dll, build, chunk, maxEvents);
    }
}

internal static class WorkerJson
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);
}
