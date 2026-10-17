# enable-ssh.ps1 - make a new laptop reachable for the installer and for support: OpenSSH server on port 22 (starts with
# Windows), firewall rule, network profile Private. Asks for administrator by itself (UAC). From a normal cmd:
#   curl -fsSLo %TEMP%\enable-ssh.ps1 https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/enable-ssh.ps1 && powershell -ExecutionPolicy Bypass -File %TEMP%\enable-ssh.ps1
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""; return
}
$ErrorActionPreference = 'Stop'
if ((Get-WindowsCapability -Online -Name 'OpenSSH.Server*').State -ne 'Installed') { Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null }
Set-Service sshd -StartupType Automatic; Start-Service sshd
if (-not (Get-NetFirewallRule -DisplayName 'OpenSSH 22' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName 'OpenSSH 22' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -Profile Any | Out-Null
}
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }).IPAddress -join ', '
Write-Host "PASS ssh on $env:COMPUTERNAME ($ip), user $env:USERNAME" -ForegroundColor Green
Read-Host 'Enter to close'
