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
    // Text kept per text node: twice what is shown, so joined pieces still fill the shown part.
    private const int MaxTextChars = MaxValueLength * 2;

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

    // Every callback catches everything itself (no lambda: a closure allocated before the try could
    // throw OutOfMemoryException outside it near the memory cap, and an exception leaving an
    // UnmanagedCallersOnly method ends the process). Losing one recorded event is better than ending
    // the worker inside a native callback; the verdict comes from XML_Parse, not from these events.
    // Names and values are only decoded while the sample still has room (#384).

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnStart(IntPtr userData, byte* name, byte** atts)
    {
        try
        {
            FlushText();
            Summary.StartElements++;
            if (HasRoom()) Add("start", Native.CString(name), Attributes(atts));
        }
        catch (Exception)
        {
            // See above: dropped on purpose.
        }
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnEnd(IntPtr userData, byte* name)
    {
        try
        {
            FlushText();
            Summary.EndElements++;
            if (HasRoom()) Add("end", Native.CString(name), "");
        }
        catch (Exception)
        {
            // See above: dropped on purpose.
        }
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnText(IntPtr userData, byte* s, int len)
    {
        try
        {
            if (s == null || len <= 0) return;
            if (s_text.Length == 0) s_textLine = CurrentLine();
            // Only the first characters are ever shown: decode at most that many bytes of a huge text node.
            if (s_text.Length < MaxTextChars)
                s_text.Append(Encoding.UTF8.GetString(new ReadOnlySpan<byte>(s, Math.Min(len, MaxTextChars))));
        }
        catch (Exception)
        {
            // See above: dropped on purpose.
        }
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnComment(IntPtr userData, byte* data)
    {
        try
        {
            FlushText();
            Summary.Comments++;
            if (HasRoom()) Add("comment", "", Native.CString(data));
        }
        catch (Exception)
        {
            // See above: dropped on purpose.
        }
    }

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnPi(IntPtr userData, byte* target, byte* data)
    {
        try
        {
            FlushText();
            Summary.ProcessingInstructions++;
            if (HasRoom()) Add("pi", Native.CString(target), Native.CString(data));
        }
        catch (Exception)
        {
            // See above: dropped on purpose.
        }
    }

    /// <summary>Call after the last XML_Parse, so trailing text is counted.</summary>
    public static void Finish() => FlushText();

    private static void FlushText()
    {
        if (s_text.Length == 0) return;
        string text = s_text.ToString();
        s_text.Clear();
        Summary.TextChunks++;
        // Whitespace between elements is counted but not shown.
        if (HasRoom() && !string.IsNullOrWhiteSpace(text))
            Add("text", "", text, s_textLine);
    }

    /// <summary>True while the sample can take another event; marks the summary truncated otherwise.</summary>
    private static bool HasRoom()
    {
        if (Summary.Sample.Count < MaxSample) return true;
        Summary.Truncated = true;
        return false;
    }

    private static void Add(string kind, string name, string value, uint? line = null)
    {
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
}
