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

# --- 3. Printer drivers ------------------------------------------------------
# ponytail: not yet - printer models and addresses are open in todo.md.

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
Get-Process javaw -ErrorAction SilentlyContinue | Where-Object Path -like "$ola\*" | Stop-Process -Force
Get-File "$ReleaseUrl/OLA-Klient.zip" "$Tmp\OLA-Klient.zip" | Out-Null
Expand-Archive -Force "$Tmp\OLA-Klient.zip" (Split-Path $ola)   # the zip holds the OLA-Klient folder
New-Item -ItemType Directory -Force "$ola\OLA6\db" | Out-Null
foreach ($f in 'ola.properties', 'SOFT.properties') {
  (Get-Content -Raw (Get-File "$BaseUrl/config/$f" "$Tmp\$f")).Replace('@OLA_SERVER@', $OlaServer).Replace('@OLA_EVENT@', $OlaEvent) |
    Set-Content -Encoding ASCII "$ola\OLA6\$f"
}
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:PUBLIC\Desktop\OLA-Klient.lnk")
$sc.TargetPath = "$ola\OLA-Klient.bat"; $sc.WorkingDirectory = $ola; $sc.WindowStyle = 7
if (Test-Path "$ola\OLA_Klient_ikon.ico") { $sc.IconLocation = "$ola\OLA_Klient_ikon.ico" } else { $sc.IconLocation = "$ola\bin\javaw.exe" }
$sc.Save()

# --- 6. Wallpaper: light grey, function and name in the upper right ---------
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
Check 'wallpaper' ((Test-Path "$Data\wallpaper.png") -and (Get-ItemProperty $csp).DesktopImageStatus -eq 1)
Write-Host $(if ($ok) { "`nPASS $Name" } else { "`nFAILED $Name - see $Data\install.log" }) -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
Stop-Transcript | Out-Null
if ($ok -and $env:COMPUTERNAME -ne $Name) {
  if ($Reboot) { Restart-Computer -Force } else { Write-Host 'Restart the laptop to use the new name.' }
}
if (-not $ok) { exit 1 }
