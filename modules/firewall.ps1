# firewall.ps1 - the event firewall switch (files/firewall-event.ps1) and its desktop icon. Installing it does not switch it on.
Step 'Event firewall switch'
Get-File "$BaseUrl/files/firewall-event.ps1" "$Data\firewall-event.ps1" | Out-Null
$lnk = "$env:PUBLIC\Desktop\Brandv$([char]0xE4)gg event.lnk"
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sc.TargetPath = 'powershell.exe'; $sc.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\firewall-event.ps1`""
$sc.IconLocation = "$env:windir\System32\FirewallControlPanel.dll,0"; $sc.Description = 'Event firewall on/off (asks for administrator)'; $sc.Save()
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Data\firewall-event.ps1" -Mode status -Quiet
Add-Check { @("event firewall switch on the desktop (now $(if (Test-Path "$Data\firewall-event.json") { 'ON' } else { 'OFF' }))", ((Test-Path "$Data\firewall-event.ps1", $lnk) -notcontains $false)) }
