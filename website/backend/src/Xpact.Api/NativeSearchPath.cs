using System.Runtime.InteropServices;

// #360 (CA5392): P/Invokes look for DLLs in System32 only, never in the working or application
// folder, so a planted kernel32.dll/advapi32.dll copy can never be picked up. xpact.dll itself is
// loaded by full path through NativeLibrary.SetDllImportResolver in the worker (Native.Load).
[assembly: DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
