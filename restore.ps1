# restore.ps1 - put a laptop back the way it was before install.ps1 (the snapshot in C:\ProgramData\10mila\restore),
# e.g. the O-Ringen laptops after 10MILA. Run from an elevated cmd:
#   curl -fsSLo %TEMP%\restore.ps1 https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/restore.ps1 && powershell -ExecutionPolicy Bypass -File %TEMP%\restore.ps1
# -KeepOla keeps an OLA MSI that install.ps1 added. Python, Acrobat Reader and drivers stay installed (listed at the end).
param([switch]$KeepOla, [switch]$Reboot)
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host 'Run this from a cmd window opened with "Run as administrator".' -ForegroundColor Red; exit 1
}
$Data = 'C:\ProgramData\10mila'; $R = "$Data\restore"
if (-not (Test-Path "$R\snapshot.json")) { Write-Host "No snapshot in ${R}: nothing to restore." -ForegroundColor Red; exit 1 }
$snap = Get-Content -Raw "$R\snapshot.json" | ConvertFrom-Json
Start-Transcript -Append "$Data\restore.log" | Out-Null
function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function ForEach-UserHive([scriptblock]$do) {   # same as install.ps1
  foreach ($u in Get-ChildItem 'C:\Users' -Directory -Force | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and (Test-Path "$($_.FullName)\NTUSER.DAT") }) {
    $key = "HKU\10mila_$($u.Name -replace '\W', '')"
    & cmd.exe /c "reg load $key `"$($u.FullName)\NTUSER.DAT`" >nul 2>&1"; $loaded = $LASTEXITCODE -eq 0
    if (-not $loaded) { $sid = (Get-CimInstance Win32_UserProfile | Where-Object LocalPath -eq $u.FullName).SID; if (-not $sid) { continue }; $key = "HKU\$sid" }
    try { & $do $key $u.Name } finally { if ($loaded) { [gc]::Collect(); & cmd.exe /c "reg unload $key >nul 2>&1" } }
  }
}

Step 'Our tasks, firewall rules and programs'
if (Test-Path "$Data\firewall-event.ps1") { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Data\firewall-event.ps1" -Mode off -Quiet }
Get-ScheduledTask -TaskName '10mila *' -ErrorAction SilentlyContinue | ForEach-Object { Stop-ScheduledTask -InputObject $_ -ErrorAction SilentlyContinue; Unregister-ScheduledTask -InputObject $_ -Confirm:$false }
Get-Process powerloss-agent -ErrorAction SilentlyContinue | Stop-Process -Force
Get-NetFirewallRule -Group '10mila', '10mila event' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Get-NetFirewallRule -DisplayName '10mila PowerLoss' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Remove-Item -Recurse -Force 'C:\Program Files\10mila' -ErrorAction SilentlyContinue
if (-not $KeepOla) {
  Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq 'OLA 6' -and $_.PSChildName -notin $snap.OlaProducts } | ForEach-Object {
      $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/x $($_.PSChildName) /qn /norestart"; Write-Host "OLA $($_.DisplayVersion) removed (exit $($p.ExitCode))"
    }
}
foreach ($p in Get-Printer | Where-Object { $_.Name -notin $snap.Printers -and $_.Type -eq 'Local' -and $_.PortName -notlike 'USB*' }) { Remove-Printer -InputObject $p; Write-Host "printer $($p.Name) removed" }

Step 'Registry'
# Keys that only we write are deleted and re-imported; shared keys are imported over (only our values change back).
$ours = '\\Policies\\Microsoft\\Power$|\\PersonalizationCSP$|\\Policies\\Microsoft\\Windows\\Control Panel\\Desktop$'
foreach ($e in $snap.Registry) {
  $user = ($e.File -replace '^user-', '') -replace '-(desktop|desktop-policy|icon-layout)\.reg$', ''
  $apply = {
    param($k)
    $target = if ($e.Root) { $e.Key.Replace($e.Root, $k) } else { $e.Key }
    if ($e.Present) {
      $text = Get-Content -Raw -Encoding Unicode "$R\reg\$($e.File)"
      if ($e.Root) { $text = $text.Replace("[$($e.Root)", "[$k") }
      $tmp = "$env:TEMP\10mila-restore.reg"; Set-Content -Encoding Unicode $tmp $text
      if ($target -match $ours) { & cmd.exe /c "reg delete `"$target`" /f >nul 2>&1" }
      & cmd.exe /c "reg import `"$tmp`" >nul 2>&1"
      if ($LASTEXITCODE -ne 0) { Write-Host "FAILED import $($e.File)" -ForegroundColor Red } else { Write-Host "$target restored" }
    } elseif ($target -match $ours) {
      & cmd.exe /c "reg delete `"$target`" /f >nul 2>&1"; Write-Host "$target removed"
    }
  }
  if ($e.Root) { ForEach-UserHive { param($k, $u) if ($u -eq $user) { & $apply $k } } } else { & $apply $null }
}
$sys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
if ($snap.PSObject.Properties.Name -notcontains 'IdleLockSecs') { } elseif ($null -eq $snap.IdleLockSecs) { Remove-ItemProperty $sys InactivityTimeoutSecs -ErrorAction SilentlyContinue } else { Set-ItemProperty $sys InactivityTimeoutSecs $snap.IdleLockSecs -Type DWord }
& cmd.exe /c "reg delete `"HKLM\SYSTEM\CurrentControlSet\Control\Print\Forms`" /v 10mila /f >nul 2>&1"

Step 'Power, network adapters, firewall, hosts'
foreach ($v in $snap.PowerValues) {
  & cmd.exe /c "powercfg /setacvalueindex $($snap.PowerScheme) $($v.Setting) $($v.AC) >nul 2>&1"
  & cmd.exe /c "powercfg /setdcvalueindex $($snap.PowerScheme) $($v.Setting) $($v.DC) >nul 2>&1"
}
& cmd.exe /c "powercfg /setactive $($snap.PowerScheme) >nul 2>&1"
if ($snap.Hibernate -eq 1) { & powercfg.exe /hibernate on }
foreach ($n in $snap.NicPowerSave) { Enable-NetAdapterPowerManagement -Name $n -NoRestart -ErrorAction SilentlyContinue }
& netsh.exe advfirewall import "$R\firewall.wfw" | Out-Null
Copy-Item -Force "$R\hosts" "$env:windir\System32\drivers\etc\hosts"

Step 'OLA settings, startup programs (BGInfo), desktops, name'
if (Test-Path "$R\OLA6") { Copy-Item -Recurse -Force "$R\OLA6\*" 'C:\ProgramData\OLA6' }
foreach ($d in Get-ChildItem "$R\startup" -Directory -ErrorAction SilentlyContinue) {
  $to = if ($d.Name -eq 'AllUsers') { 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp' } else { "C:\Users\$($d.Name)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" }
  Copy-Item -Force "$($d.FullName)\*" $to; Write-Host "startup for $($d.Name): $((Get-ChildItem $d.FullName).Name -join ', ')"
}
$desktops = @("$env:PUBLIC\Desktop") + @(Get-ChildItem C:\Users -Directory | ForEach-Object { "$($_.FullName)\Desktop" } | Where-Object { Test-Path $_ }) | Select-Object -Unique
foreach ($f in $desktops | ForEach-Object { Get-ChildItem $_ -Force -ErrorAction SilentlyContinue }) {
  if ($f.FullName -notin $snap.Desktop -and $f.Name -match '^(OLA-Klient|TA-Klient|nummerlappar|Brandv.gg event)\.(lnk|cmd)$') { Remove-Item -Force $f.FullName -ErrorAction SilentlyContinue; Write-Host "removed $($f.FullName)" }
}
if ($env:COMPUTERNAME -ne $snap.ComputerName -or (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName -ne $snap.ComputerName) {
  Rename-Computer -NewName $snap.ComputerName -Force -WarningAction SilentlyContinue; Write-Host "name back to $($snap.ComputerName) at restart"
}
Get-ChildItem C:\Users -Directory | ForEach-Object { Remove-Item -Force "$($_.FullName)\AppData\Local\10mila-wallpaper.bmp", "$($_.FullName)\AppData\Local\10mila-desktop-row.log" -ErrorAction SilentlyContinue }
Remove-Item -Force "$Data\*.ps1", "$Data\wallpaper.json", "$Data\client.json", "$Data\profile.json" -ErrorAction SilentlyContinue
Rename-Item $R "restore-done-$(Get-Date -Format yyyyMMddHHmmss)"   # a new install takes a fresh snapshot

Step 'Check'
$left = @(Get-ScheduledTask -TaskName '10mila *' -ErrorAction SilentlyContinue) + @(Get-NetFirewallRule -Group '10mila', '10mila event' -ErrorAction SilentlyContinue)
Write-Host $(if (-not $left) { 'ok       no 10mila tasks or firewall rules left' } else { 'FAILED   left: ' + ($left.Name -join ', ') })
$kept = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
  Where-Object DisplayName -match '^(Python 3\.12|Adobe Acrobat)' | ForEach-Object { "$($_.DisplayName) $($_.DisplayVersion)" })
if ($kept) { Write-Host "still installed (remove by hand if not wanted): $($kept -join '; ')" }
Write-Host $(if (-not $left) { "`nPASS restored $($snap.ComputerName)" } else { "`nFAILED restore" }) -ForegroundColor $(if (-not $left) { 'Green' } else { 'Red' })
Stop-Transcript | Out-Null
Write-Host 'Log off or restart to see the old wallpaper and desktop.'
if ($Reboot) { Restart-Computer -Force }
if ($left) { exit 1 }
