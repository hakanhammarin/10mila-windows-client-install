# install.ps1 - set up one 10MILA crew laptop.
# Run from an elevated cmd (see README.md):
#   curl -fsSLo %TEMP%\10mila.ps1 https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/install.ps1 && powershell -ExecutionPolicy Bypass -File %TEMP%\10mila.ps1
# Safe to run again: every step overwrites its own result. Ends in PASS or FAILED.
param(
  [string]$Name,                                  # e.g. TA-03; empty = pick from the list
  [string]$OlaServer = '192.168.1.21',            # OLA server on the race network
  [string]$OlaEvent  = 'tiomila2026',             # event name on the OLA server
  [string]$BaseUrl    = 'https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main',
  [string]$ReleaseUrl = 'https://github.com/hakanhammarin/10mila-windows-client-install/releases/latest/download',
  [string]$SiDriverUrl = 'https://sportident.com/download/sportident-usb-driver.2026.06.09.zip',  # signed, works on 24H2+
  [string]$BibPrinterIp = '192.168.1.27',        # OKI C542 for Nummerlappar, reached as OKIC542PS (hosts file)
  [string]$OkiDriverUrl = 'https://github.com/hakanhammarin/10mila-windows-client-install/releases/latest/download/oki-c542-ps.zip',
  [string]$PythonUrl    = 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe',
  [string]$ReaderUrl    = 'https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2600222031/AcroRdrDCx642600222031_sv_SE.exe',
  [switch]$Reboot
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
  Write-Host 'Run this from a cmd window opened with "Run as administrator".' -ForegroundColor Red; exit 1
}

$Data = 'C:\ProgramData\10mila'
$Tmp  = Join-Path $env:TEMP '10mila-install'
New-Item -ItemType Directory -Force $Data, $Tmp | Out-Null
Start-Transcript -Append (Join-Path $Data 'install.log') | Out-Null

function Get-File($url, $out) {
  & curl.exe -fsSL --retry 3 -o $out $url
  if ($LASTEXITCODE -ne 0) { throw "download failed: $url" }
  $out
}
function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }

# --- 1. Computer name and function ------------------------------------------
Step 'Computer name'
$list = Import-Csv (Get-File "$BaseUrl/computers.csv" "$Tmp\computers.csv") -Encoding UTF8 | ForEach-Object {
  $f = $_; 1..[int]$f.Count | ForEach-Object { [pscustomobject]@{ Group = $f.Group; Function = $f.Function; Name = '{0}-{1:D2}' -f $f.Prefix, $_ } }
}
if (-not $Name) {
  $funcs = @($list | Select-Object -ExpandProperty Function -Unique)
  for ($i = 0; $i -lt $funcs.Count; $i++) {
    $g = ($list | Where-Object Function -eq $funcs[$i] | Select-Object -First 1).Group
    Write-Host ('{0,3}. {1,-14} {2}' -f ($i + 1), $g, $funcs[$i])
  }
  $pick = $funcs[[int](Read-Host 'Function number') - 1]
  $names = @($list | Where-Object Function -eq $pick)
  for ($i = 0; $i -lt $names.Count; $i++) { Write-Host ('{0,3}. {1}' -f ($i + 1), $names[$i].Name) }
  $Name = $names[[int](Read-Host 'Computer number (check the label on the laptop)') - 1].Name
}
$me = $list | Where-Object Name -eq $Name.ToUpper()
if (-not $me) { throw "$Name is not in computers.csv" }
$Name = $me.Name; $Function = $me.Function
Write-Host "$Name  ($Function)"
[pscustomobject]@{ Name = $Name; Function = $Function; Group = $me.Group } | ConvertTo-Json | Set-Content -Encoding UTF8 "$Data\client.json"
if ($env:COMPUTERNAME -ne $Name) { Rename-Computer -NewName $Name -Force -WarningAction SilentlyContinue }

# --- 2. SportIdent USB driver (BSM7/BSM8, SRR dongle) -----------------------
Step 'SportIdent USB driver'
Get-File $SiDriverUrl "$Tmp\si-usb.zip" | Out-Null
Expand-Archive -Force "$Tmp\si-usb.zip" "$Tmp\si-usb"
$inf = Get-ChildItem -Recurse "$Tmp\si-usb" -Filter sportident.inf | Select-Object -First 1
& pnputil.exe /add-driver $inf.FullName /install | Out-Host   # exit 259 = installed, no reader plugged in

# --- 3. Power: never sleep, lock or save power ------------------------------
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
$hives = @(Get-ChildItem 'C:\Users' -Directory -Force | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and (Test-Path "$($_.FullName)\NTUSER.DAT") })
foreach ($u in $hives) {
  $key = "HKU\10mila_$($u.Name -replace '\W', '')"
  & cmd.exe /c "reg load $key `"$($u.FullName)\NTUSER.DAT`" >nul 2>&1"; $loaded = $LASTEXITCODE -eq 0
  if (-not $loaded) {   # in use: the user is logged on, write to the live hive
    $sid = (Get-CimInstance Win32_UserProfile | Where-Object LocalPath -eq $u.FullName).SID
    if (-not $sid) { continue }; $key = "HKU\$sid"
  }
  & reg.exe add "$key\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 0 /f | Out-Null
  & reg.exe add "$key\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaverIsSecure /t REG_SZ /d 0 /f | Out-Null
  if ($loaded) { [gc]::Collect(); & reg.exe unload $key | Out-Null }
}

# --- 4. PowerLoss agent, started at boot as SYSTEM ---------------------------
Step 'PowerLoss agent'
$pl = 'C:\Program Files\10mila\PowerLoss'
New-Item -ItemType Directory -Force $pl | Out-Null
Get-ScheduledTask -TaskName '10mila PowerLoss' -ErrorAction SilentlyContinue | Stop-ScheduledTask
Get-Process powerloss-agent -ErrorAction SilentlyContinue | Stop-Process -Force
Get-File "$ReleaseUrl/powerloss-agent.exe" "$pl\powerloss-agent.exe" | Out-Null
[IO.File]::WriteAllText("$pl\settings.json", ([pscustomobject]@{ computer_name = $Name; location = $Function; port = 3000 } | ConvertTo-Json))  # UTF-8 without BOM for Go
# ponytail: a boot-time SYSTEM task instead of a Windows service; the agent has no service handler yet (monitoring owns it).
$act = New-ScheduledTaskAction -Execute "$pl\powerloss-agent.exe" -WorkingDirectory $pl
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Register-ScheduledTask -Force -TaskName '10mila PowerLoss' -Action $act -Settings $set -Trigger (New-ScheduledTaskTrigger -AtStartup) `
  -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest) | Out-Null
Get-NetFirewallRule -DisplayName '10mila PowerLoss' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName '10mila PowerLoss' -Direction Inbound -Program "$pl\powerloss-agent.exe" -Action Allow -Profile Any | Out-Null
Start-ScheduledTask -TaskName '10mila PowerLoss'

# --- 5. OLA client -----------------------------------------------------------
Step 'OLA client'
$ola = 'C:\OLA-Klient'
if (-not (Test-Path "$ola\bin\javaw.exe")) {   # a rerun keeps the program (it may be open) and rewrites only the properties; new OLA version: delete C:\OLA-Klient\bin first
  Get-File "$ReleaseUrl/OLA-Klient.zip" "$Tmp\OLA-Klient.zip" | Out-Null
  Expand-Archive -Force "$Tmp\OLA-Klient.zip" (Split-Path $ola)   # the zip holds the OLA-Klient folder
}
New-Item -ItemType Directory -Force "$ola\OLA6\db" | Out-Null
foreach ($f in 'ola.properties', 'SOFT.properties') {
  (Get-Content -Raw (Get-File "$BaseUrl/config/$f" "$Tmp\$f")).Replace('@OLA_SERVER@', $OlaServer).Replace('@OLA_EVENT@', $OlaEvent) |
    Set-Content -Encoding ASCII "$ola\OLA6\$f"
}
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:PUBLIC\Desktop\OLA-Klient.lnk")
$sc.TargetPath = "$ola\OLA-Klient.bat"; $sc.WorkingDirectory = $ola; $sc.WindowStyle = 7
if (Test-Path "$ola\OLA_Klient_ikon.ico") { $sc.IconLocation = "$ola\OLA_Klient_ikon.ico" } else { $sc.IconLocation = "$ola\bin\javaw.exe" }
$sc.Save()

# --- 6. Nummerlappar: bib printing via Acrobat to the OKI C542 -------------
if ($me.Group -eq 'Nummerlappar') {
  Step 'Nummerlappar: printer, Python, Acrobat Reader, C:\bibs'
  $hosts = "$env:windir\System32\drivers\etc\hosts"
  $h = @(Get-Content $hosts | Where-Object { $_ -notmatch '\sOKIC542PS\s*$' }) + "$BibPrinterIp OKIC542PS"
  Set-Content -Encoding ASCII $hosts $h
  try {
    Get-File $OkiDriverUrl "$Tmp\oki.zip" | Out-Null
    Expand-Archive -Force "$Tmp\oki.zip" "$Tmp\oki"
    Get-ChildItem -Recurse "$Tmp\oki" -Filter *.inf | ForEach-Object { & pnputil.exe /add-driver $_.FullName /install | Out-Null }
    if (-not (Get-PrinterDriver 'OKI C542 PS' -ErrorAction SilentlyContinue)) { Add-PrinterDriver 'OKI C542 PS' }
    if (-not (Get-PrinterPort okic542 -ErrorAction SilentlyContinue)) { Add-PrinterPort -Name okic542 -PrinterHostAddress OKIC542PS }
    if (Get-Printer OKIC542PS -ErrorAction SilentlyContinue) { Set-Printer OKIC542PS -DriverName 'OKI C542 PS' -PortName okic542 }
    else { Add-Printer -Name OKIC542PS -DriverName 'OKI C542 PS' -PortName okic542 }
  } catch { Write-Host "OKI printer not installed: $_" -ForegroundColor Yellow }
  # Paper form "10mila" 160 x 225 mm (the bib), chosen in the driver's advanced settings.
  Add-Type -Namespace W -Name Spool -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct FORM_INFO_1 { public int Flags; public string Name; public int cx; public int cy; public int left; public int top; public int right; public int bottom; }
[StructLayout(LayoutKind.Sequential)] public struct PRINTER_DEFAULTS { public IntPtr Datatype; public IntPtr DevMode; public int DesiredAccess; }
[DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool OpenPrinter(string name, out IntPtr h, ref PRINTER_DEFAULTS d);
[DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool AddForm(IntPtr h, int level, ref FORM_INFO_1 f);
[DllImport("winspool.drv", SetLastError = true)] public static extern bool ClosePrinter(IntPtr h);
'@
  $f = New-Object W.Spool+FORM_INFO_1 -Property @{ Name = '10mila'; cx = 160000; cy = 225000; right = 160000; bottom = 225000 }   # 1/1000 mm
  $hp = [IntPtr]::Zero; $pd = New-Object W.Spool+PRINTER_DEFAULTS -Property @{ DesiredAccess = 1 }   # SERVER_ACCESS_ADMINISTER
  if ([W.Spool]::OpenPrinter("\\$env:COMPUTERNAME", [ref]$hp, [ref]$pd)) { [W.Spool]::AddForm($hp, 1, [ref]$f) | Out-Null; [W.Spool]::ClosePrinter($hp) | Out-Null }

  $py = 'C:\Program Files\Python312\python.exe'
  if (-not (Test-Path $py)) {
    Start-Process -Wait (Get-File $PythonUrl "$Tmp\python.exe") '/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_launcher=1 AssociateFiles=1'
  }
  & $py -m pip install --quiet --disable-pip-version-check --no-warn-script-location reportlab pypdf
  $acro = 'C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe'   # the path acrobat_print_2.py uses
  if (-not (Test-Path $acro)) {   # ~790 MB; no EULA flag: the operator accepts it at the first test print
    Start-Process -Wait (Get-File $ReaderUrl "$Tmp\reader.exe") '/sAll /rs /msi /norestart ALLUSERS=1 DISABLEDESKTOPSHORTCUT=1'
  }
  # Print station (C:\bibs, PDFs in C:\bibs\out_bibs are kept) and the generator (C:\bibs-prod).
  foreach ($r in @(@{ Repo = '10mila_bib_print_via_acrobat_reader_on_windows'; Dir = 'C:\bibs' }, @{ Repo = '10mila_bibs_prod'; Dir = 'C:\bibs-prod' })) {
    Get-File "https://codeload.github.com/hakanhammarin/$($r.Repo)/zip/HEAD" "$Tmp\$($r.Repo).zip" | Out-Null
    Remove-Item -Recurse -Force "$Tmp\$($r.Repo)" -ErrorAction SilentlyContinue
    Expand-Archive -Force "$Tmp\$($r.Repo).zip" "$Tmp\$($r.Repo)"
    $src = (Get-ChildItem "$Tmp\$($r.Repo)" -Directory | Select-Object -First 1).FullName
    New-Item -ItemType Directory -Force $r.Dir | Out-Null
    Get-ChildItem $src | Where-Object Name -notlike 'out_bibs*' | Copy-Item -Destination $r.Dir -Recurse -Force
  }
  New-Item -ItemType Directory -Force 'C:\bibs\out_bibs\printed' | Out-Null
  Copy-Item -Force 'C:\bibs\nummerlappar.cmd' "$env:PUBLIC\Desktop\nummerlappar.cmd"
}

# --- 7. Wallpaper: light grey, function and name in the upper right ---------
Step 'Wallpaper'
Add-Type -AssemblyName System.Drawing
$vc = Get-CimInstance Win32_VideoController | Where-Object CurrentHorizontalResolution | Select-Object -First 1
$w = [int]$(if ($vc) { $vc.CurrentHorizontalResolution } else { 1920 }); $h = [int]$(if ($vc) { $vc.CurrentVerticalResolution } else { 1080 })
$bmp = New-Object Drawing.Bitmap $w, $h
$g = [Drawing.Graphics]::FromImage($bmp)
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([Drawing.Color]::FromArgb(190, 190, 190))   # light grey: icons stand out, not bright at night
$ink = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(30, 30, 30))
$right = New-Object Drawing.StringFormat; $right.Alignment = 'Far'
$big = New-Object Drawing.Font 'Segoe UI', ([int]($h / 22)), ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
$small = New-Object Drawing.Font 'Segoe UI', ([int]($h / 36)), ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$m = [int]($h / 40)
$g.DrawString($Function, $big, $ink, [single]($w - $m), [single]$m, $right)
$g.DrawString($Name, $small, $ink, [single]($w - $m), [single]($m + $big.Height), $right)
$g.Dispose(); $bmp.Save("$Data\wallpaper.png", [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
# Machine-wide wallpaper for every user (Enterprise/IoT Enterprise), applied at logon.
$csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
New-Item -Force $csp | Out-Null
Set-ItemProperty $csp DesktopImagePath "$Data\wallpaper.png"
Set-ItemProperty $csp DesktopImageUrl "$Data\wallpaper.png"
Set-ItemProperty $csp DesktopImageStatus 1 -Type DWord

# --- Check -------------------------------------------------------------------
Step 'Check'
$ok = $true
function Check($what, $pass) { Write-Host ('{0,-8} {1}' -f $(if ($pass) { 'ok' } else { 'FAILED' }), $what); if (-not $pass) { $script:ok = $false } }
$pending = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
Check "computer name $pending (now $env:COMPUTERNAME)" ($pending -eq $Name)
Check 'SportIdent driver in the driver store' ((& pnputil.exe /enum-drivers | Out-String) -match 'SPORTident GmbH')
Start-Sleep 3
$st = try { Invoke-RestMethod -UseBasicParsing -TimeoutSec 5 http://127.0.0.1:3000/api/status } catch { $null }
Check "PowerLoss answers on :3000 (soc $($st.soc), charging $($st.is_charging))" ($null -ne $st)
Check 'OLA client and properties' ((Test-Path "$ola\bin\javaw.exe") -and ((Get-Content "$ola\OLA6\SOFT.properties") -match "lastExtURL=$OlaServer"))
$bad = @($power.Keys | Where-Object { $p = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\$_"; $p.ACSettingIndex -ne 0 -or $p.DCSettingIndex -ne 0 })
Check 'never sleeps, no screen off, lid and buttons do nothing' ($bad.Count -eq 0)
if ($me.Group -eq 'Nummerlappar') {
  Check 'printer OKIC542PS with the OKI PS driver' ((Get-Printer OKIC542PS -ErrorAction SilentlyContinue).DriverName -eq 'OKI C542 PS')
  & $py -c 'import reportlab, pypdf'
  Check 'Python with reportlab and pypdf' ($LASTEXITCODE -eq 0)
  Check 'Acrobat Reader' (Test-Path $acro)
  Check 'paper form 10mila (160 x 225 mm)' ($null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Forms' -ErrorAction SilentlyContinue).'10mila')
  Check 'C:\bibs and C:\bibs-prod' ((Test-Path 'C:\bibs\acrobat_print_2.py') -and (Test-Path 'C:\bibs-prod\bib_generator_optimized.py'))
}
Check 'wallpaper' ((Test-Path "$Data\wallpaper.png") -and (Get-ItemProperty $csp).DesktopImageStatus -eq 1)
Write-Host $(if ($ok) { "`nPASS $Name" } else { "`nFAILED $Name - see $Data\install.log" }) -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
Stop-Transcript | Out-Null
if ($ok -and $env:COMPUTERNAME -ne $Name) {
  if ($Reboot) { Restart-Computer -Force } else { Write-Host 'Restart the laptop to use the new name.' }
}
if (-not $ok) { exit 1 }
