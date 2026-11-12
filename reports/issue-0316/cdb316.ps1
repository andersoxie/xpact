param([int]$CapMb = 20, [string]$Out, [string]$WorkerDir = "c:/xpact/xpact-student-Mass/website/dist", [string]$Dll = "c:\xpact\xpact-student-Mass\website\dist\native\xpact.dll")
$ErrorActionPreference = "Stop"
$dist = $WorkerDir
$cdb = Join-Path (Get-AppxPackage Microsoft.WinDbg).InstallLocation "amd64\cdb.exe"
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class J {
  [StructLayout(LayoutKind.Sequential)] public struct BASIC { public long a,b; public uint LimitFlags; public UIntPtr c,d; public uint e; public UIntPtr f; public uint g,h; }
  [StructLayout(LayoutKind.Sequential)] public struct IO { public ulong a,b,c,d,e,f; }
  [StructLayout(LayoutKind.Sequential)] public struct EXT { public BASIC Basic; public IO Io; public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcess, PeakJob; }
  [DllImport("kernel32")] public static extern IntPtr CreateJobObject(IntPtr a, string n);
  [DllImport("kernel32")] public static extern bool SetInformationJobObject(IntPtr j, int c, ref EXT i, int l);
  [DllImport("kernel32")] public static extern bool AssignProcessToJobObject(IntPtr j, IntPtr p);
  public static IntPtr Make(ulong bytes) {
    var j = CreateJobObject(IntPtr.Zero, null); var e = new EXT();
    e.Basic.LimitFlags = 0x100 | 0x2000 | 0x400; e.ProcessMemoryLimit = (UIntPtr)bytes;
    if (!SetInformationJobObject(j, 9, ref e, Marshal.SizeOf(typeof(EXT)))) throw new Exception("SetInformationJobObject " + Marshal.GetLastWin32Error());
    return j; }
}
"@
$job = [J]::Make([uint64]$CapMb * 1MB)
# Same document as the workflow step "Memory cap inside the container"
$sb = [Text.StringBuilder]::new('<!DOCTYPE r [<!ENTITY a0 "xxxxxxxxxx">')
foreach ($i in 1..9) { [void]$sb.Append("<!ENTITY a$i `"").Append(("&a$($i - 1);" * 10)).Append('">') }
$doc = Join-Path $env:TEMP "nested316.xml"
[IO.File]::WriteAllText($doc, $sb.Append(']><r>&a9;</r>').ToString())
$cmds = 'sxd av; sxd eh; .sleep 4000; g; .echo ===EXCEPTION; .lastevent; r; .echo ===STACK; kn 120; .echo ===TEB; !teb; .echo ===ALL; ~*kn 25; q'
$p = Start-Process -FilePath $cdb -ArgumentList @("-lines", "-c", "`"$cmds`"", "`"$dist\Xpact.Worker.exe`"", "--dll", "`"$Dll`"") `
  -RedirectStandardInput $doc -RedirectStandardOutput $Out -RedirectStandardError "$Out.err" -NoNewWindow -PassThru
$w = $null
for ($t = 0; $t -lt 60 -and -not $w; $t++) { Start-Sleep -Milliseconds 100; $c = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id) AND Name='Xpact.Worker.exe'" | Select-Object -First 1; if ($c) { $w = Get-Process -Id $c.ProcessId } }
if (-not $w) { throw "worker not found" }
if (-not [J]::AssignProcessToJobObject($job, $w.Handle)) { throw "assign failed" }
"worker $($w.Id) in job, cap $CapMb MB"
$p.WaitForExit(120000) | Out-Null
"cdb exit $($p.ExitCode)"
