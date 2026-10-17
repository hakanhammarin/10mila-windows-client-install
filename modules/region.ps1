# region.ps1 - Stockholm time zone, Swedish date/time format and region; clock synced.
Step 'Time zone, format and region: Stockholm'
$rf = "$Data\restore\region.json"
if (-not (Test-Path $rf)) {   # the old settings, once, for restore.ps1
  New-Item -ItemType Directory -Force (Split-Path $rf) | Out-Null
  [pscustomobject]@{ TimeZone = (Get-TimeZone).Id; HomeGeo = (Get-WinHomeLocation).GeoId; SystemLocale = (Get-WinSystemLocale).Name; Culture = (Get-Culture).Name; User = $env:USERNAME } |
    ConvertTo-Json | Set-Content -Encoding UTF8 $rf
}
Set-TimeZone -Id 'W. Europe Standard Time'   # Stockholm (CET/CEST)
Set-WinHomeLocation -GeoId 221               # Sweden
if ((Get-WinSystemLocale).Name -ne 'sv-SE') { Set-WinSystemLocale sv-SE; Write-Host 'system locale sv-SE after restart' }
if ($env:USERNAME -ne "$env:COMPUTERNAME$") {   # not the boot update (SYSTEM): this user's formats, then copied to sign-in screen and new users
  Set-Culture sv-SE
  if (Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue) { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true }
}
& w32tm.exe /resync /nowait | Out-Null
Add-Check { $fmt = (Get-ItemProperty 'HKCU:\Control Panel\International' -ErrorAction SilentlyContinue).LocaleName   # Get-Culture shows only this process
  @("time zone $((Get-TimeZone).Id), region $((Get-WinHomeLocation).HomeLocation), format $fmt", ((Get-TimeZone).Id -eq 'W. Europe Standard Time' -and (Get-WinHomeLocation).GeoId -eq 221 -and ($fmt -eq 'sv-SE' -or $env:USERNAME -eq "$env:COMPUTERNAME$"))) }
