# wallpaper.ps1 - BGInfo replacement: Dator, Funktion, Uppgift in the upper right corner, redrawn at every logon.
# 10mila: light grey, values from client.json. oringen: the O-Ringen banner, values from C:\bgi\Funktion.txt and Uppgift.txt; BGInfo is switched off.
Step 'Wallpaper'
$style = if ($Setup -eq 'oringen') { 'oringen' } else { '10mila' }
[pscustomobject]@{ Style = $style } | ConvertTo-Json | Set-Content "$Data\wallpaper.json"
Get-File "$BaseUrl/files/wallpaper.ps1" "$Data\wallpaper.ps1" | Out-Null
Get-File "$BaseUrl/files/10mila-logo.png" "$Data\10mila-logo.png" | Out-Null
# The first version set a machine wallpaper policy; it would hide the per-user wallpaper.
$csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
if ((Get-ItemProperty $csp -ErrorAction SilentlyContinue).DesktopImagePath -like "$Data\*") { Remove-Item -Recurse -Force $csp }
Remove-Item "$Data\wallpaper.png" -ErrorAction SilentlyContinue
if ($style -eq 'oringen') {   # BGInfo off: its startup entries move to the restore folder
  $startups = @{ 'AllUsers' = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp' }
  Get-ChildItem C:\Users -Directory | ForEach-Object { $startups[$_.Name] = "$($_.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" }
  foreach ($u in $startups.Keys) {
    Get-ChildItem $startups[$u] -Filter 'BGI*.cmd' -ErrorAction SilentlyContinue | ForEach-Object {
      New-Item -ItemType Directory -Force "$Data\restore\startup\$u" | Out-Null
      Move-Item -Force $_.FullName "$Data\restore\startup\$u\$($_.Name)"; Write-Host "BGInfo off for $u"
    }
  }
}
$act = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\wallpaper.ps1`""
Register-ScheduledTask -Force -TaskName '10mila wallpaper' -Action $act -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
  -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) `
  -Principal (New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545') | Out-Null   # Users: runs in each user's own session
Start-ScheduledTask -TaskName '10mila wallpaper'   # now, for whoever is logged on
Add-Check { @("wallpaper ($style) at every logon", ((Test-Path "$Data\wallpaper.ps1") -and (Get-ScheduledTask -TaskName '10mila wallpaper' -ErrorAction SilentlyContinue))) }
if ($style -eq 'oringen') {
  Add-Check { @('BGInfo not started at logon', -not (Get-CimInstance Win32_StartupCommand | Where-Object Command -match 'BGI|bginfo')) }
}
