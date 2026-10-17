# battery.ps1 - battery test on every laptop (files/battery-log.ps1): a row a minute on battery, the runtime on the wallpaper.
Step 'Battery test'
Get-File "$BaseUrl/files/battery-log.ps1" "$Data\battery-log.ps1" | Out-Null
Get-ScheduledTask -TaskName '10mila battery' -ErrorAction SilentlyContinue | Stop-ScheduledTask
$act = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\battery-log.ps1`""
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Register-ScheduledTask -Force -TaskName '10mila battery' -Action $act -Settings $set -Trigger (New-ScheduledTaskTrigger -AtStartup) `
  -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest) | Out-Null
Start-ScheduledTask -TaskName '10mila battery'
Add-Check { $b = Get-CimInstance Win32_Battery | Select-Object -First 1
  @("battery test running (battery $(if ($b) { "$($b.EstimatedChargeRemaining) %" } else { 'none' }))", ((Get-ScheduledTask -TaskName '10mila battery').State -eq 'Running')) }
