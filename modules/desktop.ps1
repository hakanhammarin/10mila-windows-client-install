# desktop.ps1 - desktop icons in rows along the top at every logon, launch icons first (files/desktop-row.ps1).
Step 'Desktop icons in a row'
Get-File "$BaseUrl/files/desktop-row.ps1" "$Data\desktop-row.ps1" | Out-Null
$act = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\desktop-row.ps1`""
Register-ScheduledTask -Force -TaskName '10mila desktop row' -Action $act -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
  -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) `
  -Principal (New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545') | Out-Null
Start-ScheduledTask -TaskName '10mila desktop row'
Add-Check { @('desktop icons in a row at every logon', [bool](Get-ScheduledTask -TaskName '10mila desktop row' -ErrorAction SilentlyContinue)) }
