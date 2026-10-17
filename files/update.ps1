# update.ps1 - "10MILA UPDATE" (TOOLS on the desktop) and the boot task "10mila update": run the one-liner again with
# this laptop's choices (C:\ProgramData\10mila\profile.json) and the versions now in git. Without internet (event
# firewall on) or inside a freeze window it changes nothing.
param([switch]$Boot)
$data = 'C:\ProgramData\10mila'; $log = "$data\update.log"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""; return   # UAC prompt
}
$p = Get-Content -Raw "$data\profile.json" | ConvertFrom-Json
$me = "$env:TEMP\10mila-update.ps1"
& curl.exe -fsSL --max-time 30 -o $me "$($p.BaseUrl)/install.ps1"
if ($LASTEXITCODE -ne 0) {
  Add-Content $log "$(Get-Date -Format s) no connection to $($p.BaseUrl): nothing changed"
  if (-not $Boot) { Write-Host 'No internet (event firewall on?): nothing changed.' -ForegroundColor Yellow; Read-Host 'Enter to close' }
  return
}
$a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $me, '-Profile', $p.Profile, '-BaseUrl', $p.BaseUrl, '-ReleaseUrl', $p.ReleaseUrl, '-OlaServer', $p.OlaServer, '-OlaEvent', "`"$($p.OlaEvent)`"")
if ($p.Name) { $a += '-Name', $p.Name }
if ($p.Uppgift) { $a += '-Uppgift', "`"$($p.Uppgift)`"" }
$r = Start-Process powershell.exe -ArgumentList $a -Wait -PassThru -NoNewWindow
Add-Content $log "$(Get-Date -Format s) update exit $($r.ExitCode) (0 PASS, 1 FAILED, 3 frozen)"
if (-not $Boot) { Read-Host 'Enter to close' }
