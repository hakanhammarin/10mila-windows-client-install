# sportident.ps1 - SPORTident USB driver (BSM7/BSM8, SRR dongle), signed, works on 24H2+.
Step 'SportIdent USB driver'
Get-File $SiDriverUrl "$Tmp\si-usb.zip" | Out-Null
Expand-Archive -Force "$Tmp\si-usb.zip" "$Tmp\si-usb"
$inf = Get-ChildItem -Recurse "$Tmp\si-usb" -Filter sportident.inf | Select-Object -First 1
& pnputil.exe /add-driver $inf.FullName /install | Out-Host   # exit 259 = installed, no reader plugged in
# Older SPORTident drivers (6.7 from 2014: sivcp.inf, silabenm.inf) go, so readers use the signed one above.
Get-WindowsDriver -Online -ErrorAction SilentlyContinue | Where-Object { ($_.OriginalFileName -match '\\(sivcp|silabenm)\.inf$') -or ($_.ProviderName -like 'SPORTident*' -and $_.Version -notlike '11.*') } | ForEach-Object {
  & pnputil.exe /delete-driver $_.Driver /uninstall /force | Out-Null; Write-Host "old SPORTident driver $($_.Driver) ($($_.Version)) removed"
}
Add-Check { @('SportIdent driver in the driver store', ((& pnputil.exe /enum-drivers | Out-String) -match 'SPORTident GmbH')) }
