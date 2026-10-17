# update.ps1 - "10MILA UPDATE" in TOOLS on the desktop, and the same update at every boot (files/update.ps1).
Step 'Update icon and boot update'
Get-File "$BaseUrl/files/update.ps1" "$Data\update.ps1" | Out-Null
$tools = "$env:PUBLIC\Desktop\TOOLS"; New-Item -ItemType Directory -Force $tools | Out-Null
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut("$tools\10MILA UPDATE.lnk")
$sc.TargetPath = 'powershell.exe'; $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Data\update.ps1`""
$sc.IconLocation = "$env:windir\System32\shell32.dll,238"; $sc.Description = 'Update this laptop from git (asks for administrator)'; $sc.Save()
$act = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\update.ps1`" -Boot"
$trg = New-ScheduledTaskTrigger -AtStartup; $trg.Delay = 'PT2M'   # after the network is up
Register-ScheduledTask -Force -TaskName '10mila update' -Action $act -Trigger $trg `
  -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)) `
  -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest) | Out-Null
Add-Check { @('10MILA UPDATE in TOOLS and at boot', ((Test-Path "$tools\10MILA UPDATE.lnk") -and [bool](Get-ScheduledTask -TaskName '10mila update' -ErrorAction SilentlyContinue))) }
