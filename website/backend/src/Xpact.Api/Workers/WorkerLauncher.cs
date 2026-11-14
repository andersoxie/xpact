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
public sealed class WorkerLauncher(bool lowIntegrity) : IWorkerLauncher
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

            var startup = new STARTUPINFO
            {
                cb = Marshal.SizeOf<STARTUPINFO>(),
                dwFlags = StartfUseStdHandles,
                hStdInput = inRead,
                hStdOutput = outWrite,
                hStdError = errWrite,
            };
            var commandLine = new StringBuilder(CommandLine(path, arguments));
            string env = EnvironmentBlock(environment);
            uint flags = CreateSuspended | CreateUnicodeEnvironment | BelowNormalPriorityClass | CreateNoWindow;
            PROCESS_INFORMATION info;
            bool ok;
            lock (LaunchLock)
            {
                IntPtr[] childHandles = [inRead, outWrite, errWrite];
                if (childHandles.Any(child => !SetHandleInformation(child, HandleFlagInherit, HandleFlagInherit)))
                    throw new Win32Exception();
                ok = lowIntegrity
                    ? CreateProcessAsUser(token, path, commandLine, IntPtr.Zero, IntPtr.Zero, true, flags, env,
                        workingDirectory, ref startup, out info)
                    : CreateProcess(path, commandLine, IntPtr.Zero, IntPtr.Zero, true, flags, env,
                        workingDirectory, ref startup, out info);
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

            var mandatory = new TOKEN_MANDATORY_LABEL { Label = new SID_AND_ATTRIBUTES { Sid = sid, Attributes = SeGroupIntegrity } };
            int size = Marshal.SizeOf<TOKEN_MANDATORY_LABEL>() + GetLengthSid(sid);
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

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct STARTUPINFO
    {
        public int cb;
        public string? lpReserved, lpDesktop, lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PROCESS_INFORMATION
    {
        public IntPtr hProcess, hThread;
        public int dwProcessId, dwThreadId;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SID_AND_ATTRIBUTES
    {
        public IntPtr Sid;
        public uint Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct TOKEN_MANDATORY_LABEL
    {
        public SID_AND_ATTRIBUTES Label;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CreateProcess(string app, StringBuilder commandLine, IntPtr processAttributes,
        IntPtr threadAttributes, bool inheritHandles, uint flags, string environment, string currentDirectory,
        ref STARTUPINFO startup, out PROCESS_INFORMATION info);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CreateProcessAsUser(IntPtr token, string app, StringBuilder commandLine,
        IntPtr processAttributes, IntPtr threadAttributes, bool inheritHandles, uint flags, string environment,
        string currentDirectory, ref STARTUPINFO startup, out PROCESS_INFORMATION info);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool CreateRestrictedToken(IntPtr existing, uint flags, uint disableSidCount, IntPtr sidsToDisable,
        uint deletePrivilegeCount, IntPtr privilegesToDelete, uint restrictedSidCount, IntPtr sidsToRestrict, out IntPtr newToken);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool ConvertStringSidToSid(string sid, out IntPtr result);

    [DllImport("advapi32.dll")]
    private static extern int GetLengthSid(IntPtr sid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SetTokenInformation(IntPtr token, int infoClass, IntPtr info, int length);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(IntPtr token, int infoClass, IntPtr info, int length, out int returned);

    [DllImport("advapi32.dll")]
    private static extern IntPtr GetSidSubAuthorityCount(IntPtr sid);

    [DllImport("advapi32.dll")]
    private static extern IntPtr GetSidSubAuthority(IntPtr sid, uint index);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CreatePipe(out IntPtr read, out IntPtr write, IntPtr attributes, uint size);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetHandleInformation(IntPtr handle, uint mask, uint flags);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateProcess(IntPtr process, uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    internal static extern uint ResumeThread(IntPtr thread);

    [DllImport("kernel32.dll", SetLastError = true)]
    internal static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr memory);
}
