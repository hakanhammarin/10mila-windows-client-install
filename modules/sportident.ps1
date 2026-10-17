# sportident.ps1 - SPORTident USB driver (BSM7/BSM8, SRR dongle), signed, works on 24H2+.
Step 'SportIdent USB driver'
Get-File $SiDriverUrl "$Tmp\si-usb.zip" | Out-Null
Expand-Archive -Force "$Tmp\si-usb.zip" "$Tmp\si-usb"
$inf = Get-ChildItem -Recurse "$Tmp\si-usb" -Filter sportident.inf | Select-Object -First 1
& pnputil.exe /add-driver $inf.FullName /install | Out-Host   # exit 259 = installed, no reader plugged in
Add-Check { @('SportIdent driver in the driver store', ((& pnputil.exe /enum-drivers | Out-String) -match 'SPORTident GmbH')) }
