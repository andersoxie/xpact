using System.Runtime.InteropServices;
using System.Text;

namespace Xpact.Worker;

/// <summary>
/// The parts of the Expat C API (include/xpact.h) that the worker uses.
/// Same declarations as tests/dotnet/XpactDllTests/Native.cs.
/// Windows build: XML_Char = char, XML_Size = unsigned long (32 bit),
/// XML_Index = long (32 bit), calling convention cdecl.
/// </summary>
internal static unsafe class Native
{
    private const string Lib = "xpact";

    public const int StatusError = 0;
    public const int StatusOk = 1;
    public const int StatusSuspended = 2;

    /// <summary>Load the DLL at <paramref name="path"/> for every "xpact" import.</summary>
    public static void Load(string path)
    {
        string full = Path.GetFullPath(path);
        if (!File.Exists(full))
        {
            throw new FileNotFoundException("XPact DLL not found", full);
        }
        NativeLibrary.SetDllImportResolver(typeof(Native).Assembly, (name, _, _) =>
            name == Lib ? NativeLibrary.Load(full) : IntPtr.Zero);
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
    public static extern void XML_SetCommentHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, void> handler);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    public static extern void XML_SetProcessingInstructionHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, byte*, void> handler);

    public static string CString(byte* s) =>
        s == null ? "" : Encoding.UTF8.GetString(MemoryMarshal.CreateReadOnlySpanFromNullTerminated(s));
}
