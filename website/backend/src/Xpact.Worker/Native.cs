using System.Runtime.InteropServices;
using System.Text;

namespace Xpact.Worker;

/// <summary>
/// The parts of the Expat C API (include/xpact.h) that the worker uses.
/// Same declarations as tests/dotnet/XpactDllTests/Native.cs.
/// Windows build: XML_Char = char, XML_Size = unsigned long (32 bit),
/// XML_Index = long (32 bit), calling convention cdecl.
/// </summary>
internal static unsafe partial class Native
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

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial IntPtr XML_ParserCreate(byte* encoding);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial void XML_ParserFree(IntPtr parser);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial int XML_Parse(IntPtr parser, byte* s, int len, int isFinal);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial int XML_GetErrorCode(IntPtr parser);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial byte* XML_ErrorString(int code);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial uint XML_GetCurrentLineNumber(IntPtr parser);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial uint XML_GetCurrentColumnNumber(IntPtr parser);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial int XML_GetCurrentByteIndex(IntPtr parser);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial byte* XML_ExpatVersion();

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial void XML_SetStartElementHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, byte**, void> handler);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial void XML_SetEndElementHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, void> handler);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial void XML_SetCharacterDataHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, int, void> handler);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial void XML_SetCommentHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, void> handler);

    [LibraryImport(Lib)]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    public static partial void XML_SetProcessingInstructionHandler(IntPtr parser,
        delegate* unmanaged[Cdecl]<IntPtr, byte*, byte*, void> handler);

    public static string CString(byte* s) =>
        s == null ? "" : Encoding.UTF8.GetString(MemoryMarshal.CreateReadOnlySpanFromNullTerminated(s));
}
