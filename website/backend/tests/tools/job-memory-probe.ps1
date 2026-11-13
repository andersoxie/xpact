# Same Job Object limit as the API (ProcessMemoryLimit), applied to the worker started from here.
param([int] $CapMb = 45, [string] $Kind = "elements")
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class J {
  [StructLayout(LayoutKind.Sequential)] public struct B { public long a, b; public uint Flags; public UIntPtr min, max; public uint act; public UIntPtr aff; public uint pri, sch; }
  [StructLayout(LayoutKind.Sequential)] public struct IO { public ulong a,b,c,d,e,f; }
  [StructLayout(LayoutKind.Sequential)] public struct E { public B Basic; public IO Io; public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcess, PeakJob; }
  public static E Make(ulong limit) { var e = new E(); e.Basic.Flags = 0x100 | 0x2000 | 0x400; e.ProcessMemoryLimit = (UIntPtr)limit; return e; }
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr CreateJobObject(IntPtr a, string n);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetInformationJobObject(IntPtr j, int c, ref E i, uint l);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AssignProcessToJobObject(IntPtr j, IntPtr p);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool QueryInformationJobObject(IntPtr j, int c, ref E i, uint l, IntPtr r);
}
"@
$bin = "C:\Users\masou\Desktop\Lia\xpact\w12-website\website\backend\tests\Xpact.Api.Tests\bin\Release\net10.0\win-x64"
$job = [J]::CreateJobObject([IntPtr]::Zero, $null)
$e = [J]::Make([uint64]($CapMb * 1MB))
"set limit: " + [J]::SetInformationJobObject($job, 9, [ref]$e, [uint32][Runtime.InteropServices.Marshal]::SizeOf($e))
$psi = New-Object System.Diagnostics.ProcessStartInfo "$bin\Xpact.Worker.exe"
$psi.Arguments = "--dll `"$bin\native\xpact.dll`" --build production --chunk 0 --max-events 200"
$psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false
$p = [System.Diagnostics.Process]::Start($psi)
"assign: " + [J]::AssignProcessToJobObject($job, $p.Handle) + " (error " + [Runtime.InteropServices.Marshal]::GetLastWin32Error() + ")"
$xml = switch ($Kind) { "elements" { "<a>" + ("<b/>" * 100000) + "</a>" } "attr1mb" { "<a v=`"" + ("x" * 1000000) + "`"/>" } "attrs" { "<a " + ((1..1000 | ForEach-Object { "a$_=`"" + ("x" * 900) + "`"" }) -join " ") + "/>" } "expand" { "<!DOCTYPE a [<!ENTITY e `"" + ("x" * 1000) + "`">]><a>" + ("&e;" * 1000) + "</a>" } "tiny" { "<a/>" } }
$doc = [Text.Encoding]::UTF8.GetBytes($xml)
$p.StandardInput.BaseStream.Write($doc, 0, $doc.Length); $p.StandardInput.Close()
$out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd(); $p.WaitForExit()
$q = New-Object J+E; [void][J]::QueryInformationJobObject($job, 9, [ref]$q, [uint32][Runtime.InteropServices.Marshal]::SizeOf($q), [IntPtr]::Zero)
"stored: flags 0x{0:X} processLimit {1} MB" -f $q.Basic.Flags, [int]([uint64]$q.ProcessMemoryLimit / 1MB)
"cap $CapMb MB -> exit 0x{0:X8}, peak process memory in job {1} MB, verdict {2}" -f $p.ExitCode, [int]([uint64]$q.PeakProcess / 1MB), $(if ($out -match '"verdict"\s*:\s*"(\w+)"') { $Matches[1] } else { "(none)" })
if ($err) { "stderr: " + $err.Substring(0, [Math]::Min(200, $err.Length)) }
