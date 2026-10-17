# power.ps1 - never sleep, lock, dim or save power; lid and buttons do nothing; no screen saver.
Step 'Power settings'
# As machine policy (beats any older local policy and the user's own choice): 0 = never / do nothing, on AC and battery.
$power = @{
  '3C0BC021-C8A8-4E07-A973-6B14CBCB2B7E' = 'display off';      '17aaa29b-8b43-4b94-aafe-35f64daaf1ee' = 'display dim'
  '29F6C1DB-86DA-48C5-9FDB-F2B67B1F44DA' = 'sleep';            '9D7815A6-7EE4-497E-8888-515A05F02364' = 'hibernate'
  '7bc4a2f9-d8fc-4469-b07b-33eb785aaca0' = 'unattended sleep'; '6738E2C4-E8A5-4A42-B16A-E040E769756E' = 'disk off'
  '5CA83367-6E45-459F-A27B-476B1D01C936' = 'lid close';        '7648EFA3-DD9C-4E3E-B566-50F929386280' = 'power button'
  '96996BC0-AD50-47EC-923B-6F41874DD9EB' = 'sleep button';     '0e796bdb-100d-47d6-a2d5-f7d2daa51f51' = 'password on wake'
}
foreach ($g in $power.Keys) {
  $k = "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\$g"
  New-Item -Force $k | Out-Null
  Set-ItemProperty $k ACSettingIndex 0 -Type DWord; Set-ItemProperty $k DCSettingIndex 0 -Type DWord
}
& powercfg.exe /hibernate off
$usb = '2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226'   # USB selective suspend (keeps SportIdent readers awake)
# The rest has no policy: set it in the active scheme too (cmd keeps powercfg's stderr away from PowerShell's Stop).
foreach ($v in '/setacvalueindex', '/setdcvalueindex') {
  foreach ($s in 'SUB_BUTTONS UIBUTTON_ACTION', 'SUB_PCIEXPRESS ASPM', 'SUB_VIDEO VIDEOADAPT', $usb) { & cmd.exe /c "powercfg $v SCHEME_CURRENT $s 0 >nul 2>&1" }
}
& powercfg.exe /setactive SCHEME_CURRENT
Get-NetAdapter -Physical | ForEach-Object { Disable-NetAdapterPowerManagement -Name $_.Name -NoRestart -ErrorAction SilentlyContinue }   # Wi-Fi/LAN never sleep
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' InactivityTimeoutSecs 0 -Type DWord   # no idle lock
# Screen saver off for every user: policy in each profile hive, Default included (new users).
ForEach-UserHive {
  param($key)
  & reg.exe add "$key\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 0 /f | Out-Null
  & reg.exe add "$key\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaverIsSecure /t REG_SZ /d 0 /f | Out-Null
}
Add-Check {
  $bad = @($power.Keys | Where-Object { $p = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\$_"; $p.ACSettingIndex -ne 0 -or $p.DCSettingIndex -ne 0 })
  @('never sleeps, no screen off, lid and buttons do nothing', ($bad.Count -eq 0)) }
