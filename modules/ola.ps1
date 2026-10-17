# ola.ps1 - OLA client from SOFT's MSI (silent), properties in C:\ProgramData\OLA6, desktop icons for OLA-Klient and TA-Klient.
Step 'OLA client'
$ola = 'C:\Program Files\OLA 6'; $olaCfg = 'C:\ProgramData\OLA6'   # 6.5+ reads its settings from ProgramData
$all = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName -eq 'OLA 6')
$others = @($all | Where-Object DisplayVersion -ne $OlaVersion)
$have = @($all | Where-Object DisplayVersion -eq $OlaVersion).Count -gt 0
if ($others -or -not $have) {   # same version alone: keep it (it may be open)
  $msi = Get-File "$ReleaseUrl/SOFT_OLA-$OlaVersion.msi" "$Tmp\ola.msi"
  Get-CimInstance Win32_Process | Where-Object ExecutablePath -like "$ola\*" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  # SOFT changes the UpgradeCode between versions (6.5.0 -> 6.6.2), so the MSI does not replace the old one: remove it first.
  foreach ($o in $others) {
    $code = Invoke-Msi "/x $($o.PSChildName) /qn /norestart"
    if ($code -notin 0, 3010, 1605) { throw "removing OLA $($o.DisplayVersion) failed: exit $($code)" }
  }
  # Both share C:\Program Files\OLA 6 and the start menu: after removing the other version, reinstall the wanted one in full.
  $msiArgs = "/i `"$msi`"" + $(if ($have) { ' REINSTALL=ALL REINSTALLMODE=amus' } else { '' })
  $code = Invoke-Msi "$msiArgs /qn /norestart /l*v `"$Data\ola-msi.log`""
  if ($code -notin 0, 3010) { throw "OLA msi failed: exit $($code), see $Data\ola-msi.log" }
}
if (Test-Path 'C:\OLA-Klient\.installed') { Remove-Item -Recurse -Force 'C:\OLA-Klient' -ErrorAction SilentlyContinue }   # the 6.4 zip install of the first test runs
New-Item -ItemType Directory -Force "$olaCfg\db" | Out-Null
# Java properties: escape = : # ! and write non-ASCII as \uXXXX (event names have a-ring).
$ev = -join ($OlaEvent.ToCharArray() | ForEach-Object { if ([int]$_ -gt 127) { '\u{0:X4}' -f [int]$_ } elseif ('=:#!'.Contains([string]$_)) { "\$_" } else { $_ } })
foreach ($f in 'ola.properties', 'SOFT.properties') {
  (Get-Content -Raw (Get-File "$BaseUrl/config/$f" "$Tmp\$f")).Replace('@OLA_SERVER@', $OlaServer).Replace('@OLA_EVENT@', $ev) |
    Set-Content -Encoding ASCII "$olaCfg\$f"
}
Copy-Item -Force 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\OLA 6\OLA-Klient.lnk' "$env:PUBLIC\Desktop\OLA-Klient.lnk"
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:PUBLIC\Desktop\TA-Klient.lnk")   # the MSI has no shortcut for it
$sc.TargetPath = "$ola\bin\OLA-taclient.bat"; $sc.WorkingDirectory = "$ola\"; $sc.WindowStyle = 7; $sc.IconLocation = "$ola\bin\javaw.exe"; $sc.Save()
Add-Check {
  $olaNow = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName -eq 'OLA 6')
  @("OLA $OlaVersion and its properties", (($olaNow.Count -eq 1) -and ($olaNow[0].DisplayVersion -eq $OlaVersion) -and
    (Test-Path "$ola\bin\javaw.exe", "$ola\bin\OLA-Klient.bat", "$env:PUBLIC\Desktop\OLA-Klient.lnk", "$env:PUBLIC\Desktop\TA-Klient.lnk") -notcontains $false -and
    ((Get-Content "$olaCfg\SOFT.properties") -match "lastExtURL=$OlaServer"))) }
