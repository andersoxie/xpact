param([string]$WorkerDir, [string]$Label, [int[]]$Caps = @(12,14,16,18,20,22,24,26,30,40), [int]$Runs = 5,
      [string]$Dll = "c:\xpact\xpact-student-Mass\website\dist\native\xpact.dll")
# #316 cap sweep: one worker per run inside a Job Object (ProcessMemoryLimit, flags as the API), nested-entity document on stdin.
$ErrorActionPreference = "Stop"
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class J2 {
  [StructLayout(LayoutKind.Sequential)] public struct BASIC { public long a,b; public uint LimitFlags; public UIntPtr c,d; public uint e; public UIntPtr f; public uint g,h; }
  [StructLayout(LayoutKind.Sequential)] public struct IO { public ulong a,b,c,d,e,f; }
  [StructLayout(LayoutKind.Sequential)] public struct EXT { public BASIC Basic; public IO Io; public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcess, PeakJob; }
  [DllImport("kernel32")] public static extern IntPtr CreateJobObject(IntPtr a, string n);
  [DllImport("kernel32")] public static extern bool SetInformationJobObject(IntPtr j, int c, ref EXT i, int l);
  [DllImport("kernel32")] public static extern bool AssignProcessToJobObject(IntPtr j, IntPtr p);
  [DllImport("kernel32")] public static extern bool QueryInformationJobObject(IntPtr j, int c, ref EXT i, int l, IntPtr r);
  public static IntPtr Make(ulong bytes) {
    var j = CreateJobObject(IntPtr.Zero, null); var e = new EXT();
    e.Basic.LimitFlags = 0x100 | 0x2000 | 0x400; e.ProcessMemoryLimit = (UIntPtr)bytes;
    SetInformationJobObject(j, 9, ref e, Marshal.SizeOf(typeof(EXT))); return j; }
  public static ulong Peak(IntPtr j) { var e = new EXT(); QueryInformationJobObject(j, 9, ref e, Marshal.SizeOf(typeof(EXT)), IntPtr.Zero); return (ulong)e.PeakProcess; }
}
"@
$sb = [Text.StringBuilder]::new('<!DOCTYPE r [<!ENTITY a0 "xxxxxxxxxx">')
foreach ($i in 1..9) { [void]$sb.Append("<!ENTITY a$i `"").Append(("&a$($i - 1);" * 10)).Append('">') }
$doc = [Text.Encoding]::UTF8.GetBytes($sb.Append(']><r>&a9;</r>').ToString())
"== $Label ($WorkerDir)"
foreach ($cap in $Caps) {
  $outs = foreach ($r in 1..$Runs) {
    $job = [J2]::Make([uint64]$cap * 1MB)
    $psi = [Diagnostics.ProcessStartInfo]::new("$WorkerDir\Xpact.Worker.exe", "--dll `"$Dll`" --build production")
    $psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [Diagnostics.Process]::Start($psi)
    [void][J2]::AssignProcessToJobObject($job, $p.Handle)   # the worker blocks on stdin until here
    $p.StandardInput.BaseStream.Write($doc, 0, $doc.Length); $p.StandardInput.Close()
    $so = $p.StandardOutput.ReadToEndAsync(); $se = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(30000)) { $p.Kill(); "timeout"; continue }
    $peak = [math]::Round([J2]::Peak($job) / 1MB)
    if ($se.Result -match "Stack overflow") { "STACKOVERFLOW($peak)" }
    elseif ($so.Result -match '"verdict":"(\w+)"') { $v = $Matches[1]; $c = if ($so.Result -match '"code":(\d+)') { "-" + $Matches[1] } else { "" }; "$v$c($peak)" }
    else { "exit0x{0:X}($peak)" -f $p.ExitCode }
  }
  "cap $cap MB: " + (($outs | Group-Object | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ", ")
}
