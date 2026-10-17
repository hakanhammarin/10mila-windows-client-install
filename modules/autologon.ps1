# autologon.ps1 - the laptop signs in by itself at start with its current user account. The password is checked and
# kept as the LSA secret Windows reads for this (like Sysinternals Autologon), never in a file or in git.
Step 'Automatic sign-in'
$wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$user = if ($AutoLogonUser) { $AutoLogonUser } else { ((Get-CimInstance Win32_ComputerSystem).UserName -split '\\')[-1] }
if (-not $user -and $env:USERNAME -ne "$env:COMPUTERNAME$") { $user = $env:USERNAME }
$cur = Get-ItemProperty $wl -ErrorAction SilentlyContinue
$AutoLogonPassword = $env:TENMILA_AUTOLOGON_PASSWORD
if (-not $AutoLogonPassword -and $cur.AutoAdminLogon -eq '1' -and $cur.DefaultUserName -eq $user) {
  Write-Host "already on for $user"
} elseif (-not $user) {
  Write-Host 'nobody signed in to take the account from: skipped (use -AutoLogonUser)' -ForegroundColor Yellow
} else {
  if (-not $AutoLogonPassword) {
    if (-not [Environment]::UserInteractive -or $Host.Name -ne 'ConsoleHost') { Write-Host 'no password given: skipped' -ForegroundColor Yellow; return }
    $AutoLogonPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host "Password for $user (automatic sign-in)" -AsSecureString)))
  }
  Add-Type -AssemblyName System.DirectoryServices.AccountManagement
  $pc = New-Object System.DirectoryServices.AccountManagement.PrincipalContext ([System.DirectoryServices.AccountManagement.ContextType]::Machine)
  if (-not $pc.ValidateCredentials($user, $AutoLogonPassword)) { throw "wrong password for $user" }
  Add-Type -Namespace W -Name Lsa -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct ATTR { public int Length; public IntPtr a, b; public int c; public IntPtr d, e; }
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct USTR { public ushort Length, MaximumLength; public string Buffer; }
[DllImport("advapi32.dll")] public static extern uint LsaOpenPolicy(IntPtr system, ref ATTR attr, int access, out IntPtr h);
[DllImport("advapi32.dll")] public static extern uint LsaStorePrivateData(IntPtr h, ref USTR key, ref USTR data);
[DllImport("advapi32.dll")] public static extern uint LsaClose(IntPtr h);
public static uint Store(string key, string value) {
  ATTR a = new ATTR(); IntPtr h; uint r = LsaOpenPolicy(IntPtr.Zero, ref a, 0x20 | 0x800, out h); if (r != 0) return r;   // POLICY_CREATE_SECRET
  USTR k = new USTR { Buffer = key, Length = (ushort)(key.Length * 2), MaximumLength = (ushort)(key.Length * 2 + 2) };
  USTR d = new USTR { Buffer = value, Length = (ushort)(value.Length * 2), MaximumLength = (ushort)(value.Length * 2 + 2) };
  r = LsaStorePrivateData(h, ref k, ref d); LsaClose(h); return r;
}
'@
  $r = [W.Lsa]::Store('DefaultPassword', $AutoLogonPassword); if ($r -ne 0) { throw "LSA secret not stored: 0x{0:X}" -f $r }
  Set-Value $wl AutoAdminLogon '1' 'String'
  Set-Value $wl DefaultUserName $user 'String'
  Set-Value $wl DefaultDomainName $env:COMPUTERNAME 'String'
  Save-Value $wl DefaultPassword; Remove-ItemProperty $wl DefaultPassword -ErrorAction SilentlyContinue   # never in clear text
  # Windows 11 "only Windows Hello sign-in" blocks password sign-in, and with it automatic sign-in.
  Set-Value 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device' DevicePasswordLessBuildVersion 0
  Write-Host "on for $user"
}
Add-Check { $w = Get-ItemProperty $wl -ErrorAction SilentlyContinue
  @("automatic sign-in as $($w.DefaultUserName)", (($w.AutoAdminLogon -eq '1') -and $w.DefaultUserName -and -not $w.DefaultPassword)) }
