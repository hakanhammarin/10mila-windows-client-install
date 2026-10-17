# teams.ps1 - no Microsoft Teams on the event laptops: classic Teams per user, the machine-wide installer, new Teams (MSIX)
# and the Windows 11 chat app, also for users added later.
Step 'Remove Teams'
Get-Process ms-teams, Teams -ErrorAction SilentlyContinue | Stop-Process -Force
foreach ($u in Get-ChildItem C:\Users -Directory) {   # classic Teams, per user
  $up = "$($u.FullName)\AppData\Local\Microsoft\Teams\Update.exe"
  if (Test-Path $up) { Start-Process -Wait $up '--uninstall -s'; Write-Host "classic Teams removed for $($u.Name)" }
}
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
  Where-Object DisplayName -match 'Teams Machine-Wide Installer|Microsoft Teams' | ForEach-Object {
    if ($_.PSChildName -match '^\{') { Start-Process -Wait msiexec.exe "/x $($_.PSChildName) /qn /norestart"; Write-Host "$($_.DisplayName) removed" }
  }
Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object Name -in 'MSTeams', 'MicrosoftTeams' | ForEach-Object {
  Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue; Write-Host "$($_.Name) removed" }
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -in 'MSTeams', 'MicrosoftTeams' | ForEach-Object {
  Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
Set-Value 'HKLM:\SOFTWARE\Microsoft\Office\Teams' PreventInstallationFromMsi 1   # Office does not put it back
Add-Check { $left = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object Name -in 'MSTeams', 'MicrosoftTeams') + @(Get-ChildItem C:\Users\*\AppData\Local\Microsoft\Teams\current\Teams.exe -ErrorAction SilentlyContinue)
  @('no Microsoft Teams', ($left.Count -eq 0)) }
