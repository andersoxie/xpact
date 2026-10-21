using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;

namespace XpactDllTests;

/// <summary>
/// The parts of the Expat C API (include/xpact.h) that the tests use.
/// Windows build: XML_Char = char, XML_Size = unsigned long (32 bit),
/// XML_Index = long (32 bit), calling convention cdecl.
/// </summary>
internal static unsafe class Native
{
    private const string Lib = "xpact";

    public const int StatusError = 0;
    public const int StatusOk = 1;
    public const int StatusSuspended = 2;

    private static string? s_dllPath;

    /// <summary>Load the DLL at <paramref name="path"/> for every "xpact" import.</summary>
    public static void Load(string path)
    {
        s_dllPath = Path.GetFullPath(path);
        if (!File.Exists(s_dllPath))
        {
            throw new FileNotFoundException("DLL not found", s_dllPath);
        }
        NativeLibrary.SetDllImportResolver(typeof(Native).Assembly, (name, _, _) =>
            name == Lib ? NativeLibrary.Load(s_dllPath) : IntPtr.Zero);
    }

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr XML_ParserCreate(byte* encoding);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern void XML_ParserFree(IntPtr parser);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern int XML_Parse(IntPtr parser, byte* s, int len, int isFinal);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern int XML_GetErrorCode(IntPtr parser);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern byte* XML_ErrorString(int code);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint XML_GetCurrentLineNumber(IntPtr parser);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint XML_GetCurrentColumnNumber(IntPtr parser);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern int XML_GetCurrentByteIndex(IntPtr parser);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern byte* XML_ExpatVersion();

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern void XML_SetStartElementHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, byte**, void> handler);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern void XML_SetEndElementHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, void> handler);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern void XML_SetCharacterDataHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, int, void> handler);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern void XML_SetDefaultHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, int, void> handler);

    public static string CString(byte* s) =>
        s == null ? "" : Encoding.UTF8.GetString(MemoryMarshal.CreateReadOnlySpanFromNullTerminated(s));

    public static string Version() => CString(XML_ExpatVersion());
}

/// <summary>Callbacks the DLL calls. Each one appends an event to <see cref="Events"/>.</summary>
internal static unsafe class Recorder
{
    public static readonly List<string> Events = new();

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnStart(IntPtr userData, byte* name, byte** atts) =>
        Add("start:", name == null ? "(null)" : Bytes.Escape(MemoryMarshal.CreateReadOnlySpanFromNullTerminated(name)));

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnEnd(IntPtr userData, byte* name) =>
        Add("end:", name == null ? "(null)" : Bytes.Escape(MemoryMarshal.CreateReadOnlySpanFromNullTerminated(name)));

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnText(IntPtr userData, byte* s, int len) =>
        Add("text:", Slice(s, len));

    [UnmanagedCallersOnly(CallConvs = new[] { typeof(CallConvCdecl) })]
    public static void OnDefault(IntPtr userData, byte* s, int len) =>
        Add("default:", Slice(s, len));

    private static string Slice(byte* s, int len) =>
        s == null || len < 0 ? $"(bad pointer or length {len})" : Bytes.Escape(new ReadOnlySpan<byte>(s, len));

    // An exception must never leave a callback: it would take the process down.
    private static void Add(string kind, string payload)
    {
        try { Events.Add(kind + payload); } catch { }
    }
}

internal static class Bytes
{
    /// <summary>Printable ASCII as is, every other byte as \xHH, so the exact bytes stay visible.</summary>
    public static string Escape(ReadOnlySpan<byte> bytes)
    {
        var sb = new StringBuilder(bytes.Length);
        foreach (byte b in bytes)
        {
            if (b >= 0x20 && b < 0x7f && b != (byte)'\\' && b != (byte)'|')
                sb.Append((char)b);
            else
                sb.Append("\\x").Append(b.ToString("x2"));
        }
        return sb.ToString();
    }
}
