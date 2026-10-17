# wallpaper.ps1 - BGInfo replacement: Dator, Funktion, Uppgift in the upper right corner, redrawn at every logon.
# 10mila: light grey, values from client.json. oringen: the O-Ringen banner, values from C:\bgi\Funktion.txt and Uppgift.txt. BGInfo is switched off on both.
Step 'Wallpaper'
$style = if ($Setup -eq 'oringen') { 'oringen' } else { '10mila' }
Write-JsonFile ([pscustomobject]@{ Style = $style }) "$Data\wallpaper.json"
Get-File "$BaseUrl/files/wallpaper.ps1" "$Data\wallpaper.ps1" | Out-Null
Get-File "$BaseUrl/files/10mila-logo.png" "$Data\10mila-logo.png" | Out-Null
# The first version set a machine wallpaper policy; it would hide the per-user wallpaper.
$csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
if ((Get-ItemProperty $csp -ErrorAction SilentlyContinue).DesktopImagePath -like "$Data\*") { Remove-Item -Recurse -Force $csp }
Remove-Item "$Data\wallpaper.png" -ErrorAction SilentlyContinue
# BGInfo off on every laptop (it would draw over this wallpaper at logon): startup folders and Run keys; kept for restore.ps1.
$startups = @{ 'AllUsers' = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp' }
Get-ChildItem C:\Users -Directory | ForEach-Object { $startups[$_.Name] = "$($_.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" }
foreach ($u in $startups.Keys) {
  Get-ChildItem $startups[$u] -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'bgi|bginfo' } | ForEach-Object {
    New-Item -ItemType Directory -Force "$Data\restore\startup\$u" | Out-Null
    Move-Item -Force $_.FullName "$Data\restore\startup\$u\$($_.Name)"; Write-Host "BGInfo off for $u ($($_.Name))"
  }
}
$runs = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')
foreach ($k in $runs) {
  $item = Get-ItemProperty $k -ErrorAction SilentlyContinue
  foreach ($n in @($item.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' -and "$($_.Value)" -match 'bginfo|bgi\.cmd' } | ForEach-Object Name)) {
    Save-Value $k $n; Remove-ItemProperty $k $n; Write-Host "BGInfo removed from $k ($n)"
  }
}
ForEach-UserHive { param($key, $user)
  $k = "Registry::$($key -replace '^HKU\\', 'HKEY_USERS\')\Software\Microsoft\Windows\CurrentVersion\Run"
  $item = Get-ItemProperty $k -ErrorAction SilentlyContinue
  foreach ($n in @($item.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' -and "$($_.Value)" -match 'bginfo|bgi\.cmd' } | ForEach-Object Name)) {
    Save-Value $k $n "USER:$user\Software\Microsoft\Windows\CurrentVersion\Run"; Remove-ItemProperty $k $n; Write-Host "BGInfo removed from $user Run ($n)"
  }
}
$act = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\wallpaper.ps1`""
Register-ScheduledTask -Force -TaskName '10mila wallpaper' -Action $act -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
  -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) `
  -Principal (New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545') | Out-Null   # Users: runs in each user's own session
Start-ScheduledTask -TaskName '10mila wallpaper'   # now, for whoever is logged on
Add-Check { @("wallpaper ($style) at every logon", ((Test-Path "$Data\wallpaper.ps1") -and (Get-ScheduledTask -TaskName '10mila wallpaper' -ErrorAction SilentlyContinue))) }
Add-Check { @('BGInfo not started at logon', -not (Get-CimInstance Win32_StartupCommand | Where-Object Command -match 'BGI|bginfo')) }
