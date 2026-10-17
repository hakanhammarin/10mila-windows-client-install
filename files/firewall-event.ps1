# firewall-event.ps1 - event firewall on/off (desktop icon). No argument = toggle; or "on" / "off" / "status".
# On:  inbound only ssh (TCP 22), PowerLoss (TCP 3000, mDNS UDP 5353), the permanent 10mila rules (SIRAP TCP 10001) and Windows core networking (DHCP answers, IPv6 ND);
#      every outbound allow rule Windows ships is switched off and one rule allows the private addresses only
#      (RFC 1918, link-local, multicast, broadcast): no internet, so no updates.
# Off: the profiles and the rules exactly as they were before "on".
param([ValidateSet('toggle', 'on', 'off', 'status')][string]$Mode = 'toggle', [switch]$Quiet)
$ErrorActionPreference = 'Stop'
$state = 'C:\ProgramData\10mila\firewall-event.json'
$group = '10mila event'
function Say($text) {
  Write-Host $text
  if (-not $Quiet -and [Environment]::UserInteractive) { Add-Type -AssemblyName PresentationFramework; [void][Windows.MessageBox]::Show($text, '10mila event firewall') }
}
$isOn = Test-Path $state
if ($Mode -eq 'status') { Say $(if ($isOn) { 'Event firewall is ON' } else { 'Event firewall is OFF' }); return }
if ($Mode -eq 'toggle') { $Mode = if ($isOn) { 'off' } else { 'on' } }
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  # Not elevated: start again elevated, Windows shows the UAC prompt.
  $a = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode $Mode" + $(if ($Quiet) { ' -Quiet' } else { '' })
  Start-Process powershell.exe -Verb RunAs -ArgumentList $a; return
}
$private4 = '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '169.254.0.0/16', '224.0.0.0/4', '255.255.255.255'   # loopback is always allowed
$private6 = 'fe80::/10', 'fc00::/7'   # the firewall refuses IPv6 multicast and loopback here
if ($Mode -eq 'on') {
  if ($isOn) { Say 'Event firewall is already ON'; return }
  $profiles = Get-NetFirewallProfile | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Enabled = "$($_.Enabled)"; In = "$($_.DefaultInboundAction)"; Out = "$($_.DefaultOutboundAction)" } }
  # Allow rules that would let more through: switched off now, back on with "off". Inbound core networking (DHCP) stays.
  $core = Get-NetFirewallRule -Group '@FirewallAPI.dll,-25000' -ErrorAction SilentlyContinue | ForEach-Object Name
  $disabled = @(Get-NetFirewallRule -Action Allow -Enabled True | Where-Object { $_.Group -notin $group, '10mila' -and -not ($_.Direction -eq 'Inbound' -and $_.Name -in $core) } | ForEach-Object Name)
  [pscustomobject]@{ Profiles = $profiles; Disabled = $disabled; On = (Get-Date -Format s) } | ConvertTo-Json -Depth 3 | Set-Content "$state.tmp"; Move-Item -Force "$state.tmp" $state   # survives a power cut
  try {
  if ($disabled) { Disable-NetFirewallRule -Name $disabled }
  Get-NetFirewallRule -Group $group -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  New-NetFirewallRule -Group $group -DisplayName '10mila event: ssh in' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow | Out-Null
  New-NetFirewallRule -Group $group -DisplayName '10mila event: PowerLoss in' -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow | Out-Null
  New-NetFirewallRule -Group $group -DisplayName '10mila event: mDNS in' -Direction Inbound -Protocol UDP -LocalPort 5353 -Action Allow | Out-Null
  New-NetFirewallRule -Group $group -DisplayName '10mila event: private out' -Direction Outbound -RemoteAddress ($private4 + $private6) -Action Allow | Out-Null
  Set-NetFirewallProfile -All -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Block
  } catch {   # half on is worse than off: undo and say so
    $err = $_; & $PSCommandPath -Mode off -Quiet; Say "Event firewall NOT switched on: $err"; exit 1
  }
  Start-ScheduledTask -TaskName '10mila wallpaper' -ErrorAction SilentlyContinue   # the status line on the desktop
  Say 'Event firewall is ON: only the local network, no internet.'
} else {
  if (-not $isOn) { Say 'Event firewall is already OFF'; return }
  $s = Get-Content -Raw $state | ConvertFrom-Json
  Get-NetFirewallRule -Group $group -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  foreach ($p in $s.Profiles) { Set-NetFirewallProfile -Name $p.Name -Enabled $p.Enabled -DefaultInboundAction $p.In -DefaultOutboundAction $p.Out }
  if ($s.Disabled) { Enable-NetFirewallRule -Name @($s.Disabled) -ErrorAction SilentlyContinue }
  Remove-Item $state
  Start-ScheduledTask -TaskName '10mila wallpaper' -ErrorAction SilentlyContinue   # the status line on the desktop
  Say 'Event firewall is OFF: back to normal.'
}
