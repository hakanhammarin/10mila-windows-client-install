# receipt.ps1 - Star TSP100 (TSP143) receipt printer: driver, and "Hello world" at boot and when it is plugged in.
Step 'Receipt printer (Star TSP143)'
if (-not (Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object Name -like 'Star TSP100*')) {   # Star's smjt100 driver, exported from an O-Ringen laptop
  Get-File "$ReleaseUrl/star-tsp100.zip" "$Tmp\star.zip" | Out-Null
  Expand-Archive -Force "$Tmp\star.zip" "$Tmp\star"
  & pnputil.exe /add-driver "$Tmp\star\smjt100.inf" /install | Out-Null
  Add-PrinterDriver 'Star TSP100 Cutter (TSP143)'
}
Get-File "$BaseUrl/files/receipt-watch.ps1" "$Data\receipt-watch.ps1" | Out-Null
Get-ScheduledTask -TaskName '10mila receipt hello' -ErrorAction SilentlyContinue | Stop-ScheduledTask
$act = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\receipt-watch.ps1`""
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Register-ScheduledTask -Force -TaskName '10mila receipt hello' -Action $act -Settings $set -Trigger (New-ScheduledTaskTrigger -AtStartup) `
  -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest) | Out-Null
Start-ScheduledTask -TaskName '10mila receipt hello'   # prints now if the printer is plugged in
Add-Check { @('Star driver and the hello world watcher', ((Get-PrinterDriver -ErrorAction SilentlyContinue | Where-Object Name -like 'Star TSP100*') -and
  ((Get-ScheduledTask -TaskName '10mila receipt hello').State -eq 'Running'))) }
