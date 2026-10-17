# siconfig.ps1 - SPORTident Config+ (program the stations and readers) on every laptop, its icon in TOOLS.
Step 'SPORTident Config+'
$have = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName -like '*Config+*' | Select-Object -First 1
if (-not $have -or [version]$have.DisplayVersion -lt [version]$SiConfigVersion) {
  $msi = Get-File "https://sportident.com/siupdate/si_config_plus/release/sportident_configplus_setup_$SiConfigVersion.msi" "$Tmp\siconfig.msi"
  $code = Invoke-Msi "/i `"$msi`" /qn /norestart ALLUSERS=1 /l*v `"$Data\siconfig-msi.log`""
  if ($code -notin 0, 3010) { throw "Config+ msi failed: exit $($code), see $Data\siconfig-msi.log" }
}
$tools = "$env:PUBLIC\Desktop\TOOLS"; New-Item -ItemType Directory -Force $tools | Out-Null
$lnk = Get-ChildItem 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs' -Recurse -Filter '*Config*.lnk' -ErrorAction SilentlyContinue | Where-Object Name -match 'SPORTident|Config\+' | Select-Object -First 1
if ($lnk) { Copy-Item -Force $lnk.FullName "$tools\SPORTident Config+.lnk" }
Get-ChildItem "$env:PUBLIC\Desktop" -Filter '*Config*.lnk' | Where-Object Name -match 'SPORTident' | Remove-Item -Force   # the MSI's own desktop icon: TOOLS has it
Add-Check { @('SPORTident Config+ in TOOLS', (Test-Path "$tools\SPORTident Config+.lnk")) }
