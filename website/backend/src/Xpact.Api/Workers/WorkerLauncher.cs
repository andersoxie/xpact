using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Xpact.Api.Workers;

/// <summary>A started, still suspended worker with its redirected standard streams.</summary>
public sealed class WorkerProcess : IDisposable
{
    private IntPtr _process;
    private IntPtr _thread;

    internal WorkerProcess(IntPtr process, IntPtr thread, int id, Stream input, Stream output, Stream error)
    {
        _process = process;
        _thread = thread;
        Process = Process.GetProcessById(id);
        StandardInput = input;
        StandardOutput = new StreamReader(output, Encoding.UTF8);
        StandardError = new StreamReader(error, Encoding.UTF8);
    }

    public Process Process { get; }
    public Stream StandardInput { get; }
    public StreamReader StandardOutput { get; }
    public StreamReader StandardError { get; }

    /// <summary>Let the worker run. Call after it has been put under its limits.</summary>
    public void Resume()
    {
        if (WorkerLauncher.ResumeThread(_thread) == uint.MaxValue) throw new Win32Exception();
    }

    public void Dispose()
    {
        StandardInput.Dispose();
        StandardOutput.Dispose();
        StandardError.Dispose();
        Process.Dispose();
        if (_thread != IntPtr.Zero) { WorkerLauncher.CloseHandle(_thread); _thread = IntPtr.Zero; }
        if (_process != IntPtr.Zero) { WorkerLauncher.CloseHandle(_process); _process = IntPtr.Zero; }
    }
}

/// <summary>Starts worker processes suspended, so their limits are set before they run any code.</summary>
public interface IWorkerLauncher
{
    WorkerProcess Start(string path, IReadOnlyList<string> arguments, IDictionary<string, string?> environment,
        string workingDirectory);
}

/// <summary>
/// Starts the worker with <c>CreateProcess(AsUser)</c>, suspended, at below-normal priority, with no window
/// and only its three pipe handles inherited. With <c>lowIntegrity</c> (the default) the worker gets a copy of
/// the API's token with every privilege removed and the <b>Low</b> integrity level: it can still read the
/// worker and DLL files, but it cannot write to files, registry keys or processes of the API's account.
/// No extra Windows account is needed.
/// </summary>
public sealed partial class WorkerLauncher(bool lowIntegrity) : IWorkerLauncher
{
    private const uint CreateSuspended = 0x00000004;
    private const uint CreateUnicodeEnvironment = 0x00000400;
    private const uint BelowNormalPriorityClass = 0x00004000;
    private const uint CreateNoWindow = 0x08000000;
    private const int StartfUseStdHandles = 0x00000100;
    private const uint HandleFlagInherit = 0x00000001;
    private const uint DisableMaxPrivilege = 0x1;
    private const uint SeGroupIntegrity = 0x00000020;
    private const int TokenIntegrityLevel = 25;
    private const uint TokenAll = 0x000F01FF;
    internal const string LowIntegritySid = "S-1-16-4096";

    // Only one launch at a time: the child ends of the pipes are inheritable for a moment, and a worker
    // started in parallel must not inherit another worker's pipe (its output would then never end).
    private static readonly object LaunchLock = new();

    public bool LowIntegrity => lowIntegrity;

    public WorkerProcess Start(string path, IReadOnlyList<string> arguments, IDictionary<string, string?> environment,
        string workingDirectory)
    {
        var handles = new List<IntPtr>();
        IntPtr token = IntPtr.Zero;
        try
        {
            if (lowIntegrity) token = LowIntegrityToken();

            CreatePipePair(out IntPtr inRead, out IntPtr inWrite, handles);
            CreatePipePair(out IntPtr outRead, out IntPtr outWrite, handles);
            CreatePipePair(out IntPtr errRead, out IntPtr errWrite, handles);

            var startup = new StartupInfo
            {
                cb = Marshal.SizeOf<StartupInfo>(),
                dwFlags = StartfUseStdHandles,
                hStdInput = inRead,
                hStdOutput = outWrite,
                hStdError = errWrite,
            };
            // CreateProcess may write into the command line: a private, NUL-terminated buffer.
            char[] commandLine = (CommandLine(path, arguments) + "\0").ToCharArray();
            string env = EnvironmentBlock(environment);
            uint flags = CreateSuspended | CreateUnicodeEnvironment | BelowNormalPriorityClass | CreateNoWindow;
            ProcessInformation info;
            bool ok;
            lock (LaunchLock)
            {
                IntPtr[] childHandles = [inRead, outWrite, errWrite];
                if (childHandles.Any(child => !SetHandleInformation(child, HandleFlagInherit, HandleFlagInherit)))
                    throw new Win32Exception();
                unsafe
                {
                    fixed (char* command = commandLine)
                    {
                        ok = lowIntegrity
                            ? CreateProcessAsUser(token, path, command, IntPtr.Zero, IntPtr.Zero, true, flags, env,
                                workingDirectory, ref startup, out info)
                            : CreateProcess(path, command, IntPtr.Zero, IntPtr.Zero, true, flags, env,
                                workingDirectory, ref startup, out info);
                    }
                }
                int error = Marshal.GetLastWin32Error();
                foreach (IntPtr child in new[] { inRead, outWrite, errWrite })
                {
                    CloseHandle(child);
                    handles.Remove(child);
                }
                if (!ok) throw new Win32Exception(error);
            }

            try
            {
                var process = new WorkerProcess(info.hProcess, info.hThread, info.dwProcessId,
                    Wrap(inWrite, FileAccess.Write), Wrap(outRead, FileAccess.Read), Wrap(errRead, FileAccess.Read));
                handles.Clear(); // now owned by the streams
                return process;
            }
            catch
            {
                TerminateProcess(info.hProcess, 1);
                CloseHandle(info.hThread);
                CloseHandle(info.hProcess);
                throw;
            }
        }
        finally
        {
            foreach (IntPtr h in handles) CloseHandle(h);
            if (token != IntPtr.Zero) CloseHandle(token);
        }
    }

    /// <summary>A copy of this process's token without privileges and at the Low integrity level.</summary>
    private static IntPtr LowIntegrityToken()
    {
        if (!OpenProcessToken(GetCurrentProcess(), TokenAll, out IntPtr own)) throw new Win32Exception();
        IntPtr restricted = IntPtr.Zero, sid = IntPtr.Zero, label = IntPtr.Zero;
        try
        {
            if (!CreateRestrictedToken(own, DisableMaxPrivilege, 0, IntPtr.Zero, 0, IntPtr.Zero, 0, IntPtr.Zero, out restricted))
                throw new Win32Exception();
            if (!ConvertStringSidToSid(LowIntegritySid, out sid)) throw new Win32Exception();

            var mandatory = new TokenMandatoryLabel { Label = new SidAndAttributes { Sid = sid, Attributes = SeGroupIntegrity } };
            int size = Marshal.SizeOf<TokenMandatoryLabel>() + GetLengthSid(sid);
            label = Marshal.AllocHGlobal(size);
            Marshal.StructureToPtr(mandatory, label, false);
            if (!SetTokenInformation(restricted, TokenIntegrityLevel, label, size)) throw new Win32Exception();

            IntPtr result = restricted;
            restricted = IntPtr.Zero;
            return result;
        }
        finally
        {
            if (label != IntPtr.Zero) Marshal.FreeHGlobal(label);
            if (sid != IntPtr.Zero) LocalFree(sid);
            if (restricted != IntPtr.Zero) CloseHandle(restricted);
            CloseHandle(own);
        }
    }

    private static void CreatePipePair(out IntPtr read, out IntPtr write, List<IntPtr> handles)
    {
        // Created not inheritable; the child's end is made inheritable only inside the launch lock.
        if (!CreatePipe(out read, out write, IntPtr.Zero, 0)) throw new Win32Exception();
        handles.Add(read);
        handles.Add(write);
    }

    private static FileStream Wrap(IntPtr handle, FileAccess access) =>
        new(new SafeFileHandle(handle, ownsHandle: true), access, 4096, isAsync: false);

    /// <summary>Windows command-line quoting (the rules CommandLineToArgvW and the C runtime read back).</summary>
    internal static string CommandLine(string path, IReadOnlyList<string> arguments)
    {
        var sb = new StringBuilder();
        Append(sb, path);
        foreach (string a in arguments)
        {
            sb.Append(' ');
            Append(sb, a);
        }
        return sb.ToString();

        static void Append(StringBuilder sb, string arg)
        {
            if (arg.Length > 0 && arg.IndexOfAny([' ', '\t', '\n', '\v', '"']) < 0)
            {
                sb.Append(arg);
                return;
            }
            sb.Append('"');
            int backslashes = 0;
            foreach (char c in arg)
            {
                if (c == '\\') { backslashes++; continue; }
                if (c == '"') sb.Append('\\', 2 * backslashes + 1);
                else sb.Append('\\', backslashes);
                backslashes = 0;
                sb.Append(c);
            }
            sb.Append('\\', 2 * backslashes).Append('"');
        }
    }

    private static string EnvironmentBlock(IDictionary<string, string?> environment)
    {
        var sb = new StringBuilder();
        foreach (var (key, value) in environment.OrderBy(e => e.Key, StringComparer.OrdinalIgnoreCase))
            if (value is not null) sb.Append(key).Append('=').Append(value).Append('\0');
        return sb.Append('\0').ToString();
    }

    /// <summary>The integrity level RID of a process (4096 = Low, 8192 = Medium, 12288 = High).</summary>
    public static int IntegrityLevel(Process process)
    {
        if (!OpenProcessToken(process.Handle, 0x0008 /* TOKEN_QUERY */, out IntPtr token)) throw new Win32Exception();
        try
        {
            GetTokenInformation(token, TokenIntegrityLevel, IntPtr.Zero, 0, out int size);
            IntPtr buffer = Marshal.AllocHGlobal(size);
            try
            {
                if (!GetTokenInformation(token, TokenIntegrityLevel, buffer, size, out _)) throw new Win32Exception();
                IntPtr sid = Marshal.ReadIntPtr(buffer);
                IntPtr count = GetSidSubAuthorityCount(sid);
                return Marshal.ReadInt32(GetSidSubAuthority(sid, (uint)(Marshal.ReadByte(count) - 1)));
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }
        finally
        {
            CloseHandle(token);
        }
    }

    /// <summary>Number of privileges in a process's token (the low-integrity worker keeps only SeChangeNotify).</summary>
    public static int PrivilegeCount(Process process)
    {
        if (!OpenProcessToken(process.Handle, 0x0008, out IntPtr token)) throw new Win32Exception();
        try
        {
            GetTokenInformation(token, 3 /* TokenPrivileges */, IntPtr.Zero, 0, out int size);
            IntPtr buffer = Marshal.AllocHGlobal(size);
            try
            {
                if (!GetTokenInformation(token, 3, buffer, size, out _)) throw new Win32Exception();
                return Marshal.ReadInt32(buffer);
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }
        finally
        {
            CloseHandle(token);
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct StartupInfo
    {
        public int cb;
        public IntPtr lpReserved, lpDesktop, lpTitle; // unused (null); IntPtr keeps the struct blittable
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInformation
    {
        public IntPtr hProcess, hThread;
        public int dwProcessId, dwThreadId;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SidAndAttributes
    {
        public IntPtr Sid;
        public uint Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct TokenMandatoryLabel
    {
        public SidAndAttributes Label;
    }

    [LibraryImport("kernel32.dll", EntryPoint = "CreateProcessW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static unsafe partial bool CreateProcess(string app, char* commandLine, IntPtr processAttributes,
        IntPtr threadAttributes, [MarshalAs(UnmanagedType.Bool)] bool inheritHandles, uint flags, string environment, string currentDirectory,
        ref StartupInfo startup, out ProcessInformation info);

    [LibraryImport("advapi32.dll", EntryPoint = "CreateProcessAsUserW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static unsafe partial bool CreateProcessAsUser(IntPtr token, string app, char* commandLine,
        IntPtr processAttributes, IntPtr threadAttributes, [MarshalAs(UnmanagedType.Bool)] bool inheritHandles, uint flags, string environment,
        string currentDirectory, ref StartupInfo startup, out ProcessInformation info);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CreateRestrictedToken(IntPtr existing, uint flags, uint disableSidCount, IntPtr sidsToDisable,
        uint deletePrivilegeCount, IntPtr privilegesToDelete, uint restrictedSidCount, IntPtr sidsToRestrict, out IntPtr newToken);

    [LibraryImport("advapi32.dll", EntryPoint = "ConvertStringSidToSidW", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool ConvertStringSidToSid(string sid, out IntPtr result);

    [LibraryImport("advapi32.dll")]
    private static partial int GetLengthSid(IntPtr sid);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool SetTokenInformation(IntPtr token, int infoClass, IntPtr info, int length);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetTokenInformation(IntPtr token, int infoClass, IntPtr info, int length, out int returned);

    [LibraryImport("advapi32.dll")]
    private static partial IntPtr GetSidSubAuthorityCount(IntPtr sid);

    [LibraryImport("advapi32.dll")]
    private static partial IntPtr GetSidSubAuthority(IntPtr sid, uint index);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CreatePipe(out IntPtr read, out IntPtr write, IntPtr attributes, uint size);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool SetHandleInformation(IntPtr handle, uint mask, uint flags);

    [LibraryImport("kernel32.dll")]
    private static partial IntPtr GetCurrentProcess();

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool TerminateProcess(IntPtr process, uint exitCode);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    internal static partial uint ResumeThread(IntPtr thread);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool CloseHandle(IntPtr handle);

    [LibraryImport("kernel32.dll")]
    private static partial IntPtr LocalFree(IntPtr memory);
}
