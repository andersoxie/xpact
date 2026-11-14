using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using Xpact.Contracts;

namespace Xpact.Worker;

/// <summary>
/// Callbacks the DLL calls. They count every event and keep the first ones as a sample.
/// One worker process parses one document, so static state is safe here.
/// </summary>
internal static unsafe class EventRecorder
{
    private const int MaxValueLength = 200;

    public static EventSummary Summary { get; private set; } = new();
    public static IntPtr Parser { get; set; }
    public static int MaxSample { get; set; } = 200;

    // Expat may split character data into several callbacks; adjacent pieces are joined.
    private static readonly StringBuilder s_text = new();
    private static uint s_textLine;

    public static void Reset(int maxSample)
    {
        Summary = new EventSummary();
        MaxSample = maxSample;
        s_text.Clear();
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnStart(IntPtr userData, byte* name, byte** atts) => Guard(() =>
    {
        FlushText();
        Summary.StartElements++;
        Add("start", Native.CString(name), Attributes(atts));
    });

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnEnd(IntPtr userData, byte* name) => Guard(() =>
    {
        FlushText();
        Summary.EndElements++;
        Add("end", Native.CString(name), "");
    });

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnText(IntPtr userData, byte* s, int len) => Guard(() =>
    {
        if (s == null || len <= 0) return;
        if (s_text.Length == 0) s_textLine = CurrentLine();
        if (s_text.Length < MaxValueLength * 2)
            s_text.Append(Encoding.UTF8.GetString(new ReadOnlySpan<byte>(s, len)));
    });

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnComment(IntPtr userData, byte* data) => Guard(() =>
    {
        FlushText();
        Summary.Comments++;
        Add("comment", "", Native.CString(data));
    });

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnPi(IntPtr userData, byte* target, byte* data) => Guard(() =>
    {
        FlushText();
        Summary.ProcessingInstructions++;
        Add("pi", Native.CString(target), Native.CString(data));
    });

    /// <summary>Call after the last XML_Parse, so trailing text is counted.</summary>
    public static void Finish() => FlushText();

    private static void FlushText()
    {
        if (s_text.Length == 0) return;
        string text = s_text.ToString();
        s_text.Clear();
        Summary.TextChunks++;
        // Whitespace between elements is counted but not shown.
        if (!string.IsNullOrWhiteSpace(text))
            Add("text", "", text, s_textLine);
    }

    private static void Add(string kind, string name, string value, uint? line = null)
    {
        if (Summary.Sample.Count >= MaxSample)
        {
            Summary.Truncated = true;
            return;
        }
        Summary.Sample.Add(new ParseEvent
        {
            Kind = kind,
            Name = name,
            Value = Shorten(value),
            Line = line ?? CurrentLine(),
        });
    }

    private static string Attributes(byte** atts)
    {
        if (atts == null) return "";
        var sb = new StringBuilder();
        for (int i = 0; atts[i] != null && atts[i + 1] != null; i += 2)
        {
            if (sb.Length > 0) sb.Append(' ');
            sb.Append(Native.CString(atts[i])).Append("=\"").Append(Native.CString(atts[i + 1])).Append('"');
        }
        return sb.ToString();
    }

    private static uint CurrentLine() =>
        Parser == IntPtr.Zero ? 0 : Native.XML_GetCurrentLineNumber(Parser);

    private static string Shorten(string s) =>
        s.Length <= MaxValueLength ? s : s[..MaxValueLength] + "…";

    // An exception must never leave a callback: it would take the process down.
    private static void Guard(Action action)
    {
        try
        {
            action();
        }
        catch (Exception)
        {
            // Dropped on purpose: losing one recorded event is better than ending the worker
            // inside a native callback. The verdict comes from XML_Parse, not from these events.
        }
    }
}
