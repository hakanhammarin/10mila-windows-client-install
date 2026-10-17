# install.ps1 - set up one crew laptop: loads the modules of a profile from modules/ and ends in PASS or FAILED.
# Run from an elevated cmd (see README.md):
#   curl -fsSLo %TEMP%\10mila.ps1 https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/install.ps1 && powershell -ExecutionPolicy Bypass -File %TEMP%\10mila.ps1
# Safe to run again. The first run saves what it will change (C:\ProgramData\10mila\restore); restore.ps1 puts it back.
param(
  [Alias('Profile')][string]$Setup = '10mila',    # -Profile 10mila | oringen (see $profiles below)
  [string[]]$Modules,                             # run only these modules, e.g. -Modules firewall,receipt
  [string]$Name,                                  # 10mila: e.g. TA-03; empty = pick from the list
  [string]$Uppgift = '',                          # 10mila: the "Uppgift" line on the wallpaper (empty = none)
  [string]$OlaServer = '192.168.1.21',            # OLA server on the race network
  [string]$OlaEvent  = "Tiomila, Tran$([char]0xE5)s (Stafettligan, #3)",   # event name on the OLA server (2026); file stays ASCII for PowerShell 5.1
  [string]$OlaVersion = '6.6.2',                  # SOFT_OLA-<version>.msi in the release
  [string]$BaseUrl    = 'https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main',
  [string]$ReleaseUrl = 'https://github.com/hakanhammarin/10mila-windows-client-install/releases/latest/download',
  [string]$SiDriverUrl = 'https://sportident.com/download/sportident-usb-driver.2026.06.09.zip',  # signed, works on 24H2+
  [string]$BibPrinterIp = '192.168.1.27',        # OKI C542 for Nummerlappar, reached as OKIC542PS (hosts file)
  [string]$OkiDriverUrl = 'https://github.com/hakanhammarin/10mila-windows-client-install/releases/latest/download/oki-c542-ps.zip',
  [string]$PythonUrl    = 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe',
  [string]$ReaderUrl    = 'https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2600222031/AcroRdrDCx642600222031_sv_SE.exe',
  [string]$AutoLogonUser,                         # automatic sign-in: default the user signed in now; password asked for, or
                                                  # from $env:TENMILA_AUTOLOGON_PASSWORD (a parameter would land in install.log)
  [string]$LibreOfficeVersion = '26.8.1',          # O-Ringen profile; from download.documentfoundation.org
  [string]$SimulateNow,                           # test the freeze windows: e.g. '2027-05-01 10:00'
  [switch]$Reboot
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Profiles: which modules, in order. backup always runs first so restore.ps1 can undo the rest.
$profiles = @{
  '10mila'  = 'name', 'region', 'sportident', 'power', 'autologon', 'powerloss', 'ola', 'nummerlappar', 'receipt', 'battery', 'firewall', 'update', 'wallpaper', 'desktop', 'taskbar'
  'oringen' = 'region', 'power', 'autologon', 'libreoffice', 'receipt', 'battery', 'firewall', 'update', 'wallpaper', 'desktop', 'taskbar'
}
$Modules = @($Modules | ForEach-Object { $_ -split ',' } | Where-Object { $_ })   # powershell -File passes a,b as one string
if (-not $Modules) { $Modules = $profiles[$Setup] }
if (-not $Modules) { throw "unknown profile $Setup (known: $($profiles.Keys -join ', '))" }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
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
$Checks = New-Object Collections.Generic.List[scriptblock]
function Add-Check([scriptblock]$test) { $Checks.Add($test) }   # the block returns @(text, passed)
# Run $do with each user profile's registry hive (Default included); a logged-on user's live hive is used as it is.
function ForEach-UserHive([scriptblock]$do) {
  foreach ($u in Get-ChildItem 'C:\Users' -Directory -Force | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and (Test-Path "$($_.FullName)\NTUSER.DAT") }) {
    $key = "HKU\10mila_$($u.Name -replace '\W', '')"
    & cmd.exe /c "reg load $key `"$($u.FullName)\NTUSER.DAT`" >nul 2>&1"; $loaded = $LASTEXITCODE -eq 0
    if (-not $loaded) {
      $sid = (Get-CimInstance Win32_UserProfile | Where-Object LocalPath -eq $u.FullName).SID
      if (-not $sid) { continue }; $key = "HKU\$sid"
    }
    try { & $do $key $u.Name } finally { if ($loaded) { [gc]::Collect(); & cmd.exe /c "reg unload $key >nul 2>&1" } }
  }
}
# Freeze windows (freeze.csv in git): no install or update runs inside one, e.g. the race weekend.
$now = if ($SimulateNow) { [datetime]$SimulateNow } else { Get-Date }
$frozen = Import-Csv (Get-File "$BaseUrl/freeze.csv" "$Tmp\freeze.csv") | Where-Object { $now -ge [datetime]$_.Start -and $now -le [datetime]$_.End } | Select-Object -First 1
if ($frozen) {
  Write-Host "FROZEN until $($frozen.End): $($frozen.Label). Nothing was changed." -ForegroundColor Yellow
  Stop-Transcript | Out-Null; exit 3
}
if ($SimulateNow) { Write-Host "not frozen at $SimulateNow" }
# Remember a registry value before a module changes it, for restore.ps1 (values.json; the first value seen wins).
$valuesFile = "$Data\restore\values.json"
# $id names the place for restore.ps1: the path itself, or USER:<user>\<subkey> for a user's hive (loaded under another name later).
function Save-Value($path, $name, $id = $path) {
  $list = @(if (Test-Path $valuesFile) { Get-Content -Raw $valuesFile | ConvertFrom-Json })
  if ($list | Where-Object { $_.Path -eq $id -and $_.Name -eq $name }) { return }
  $item = Get-ItemProperty -LiteralPath $path -Name $name -ErrorAction SilentlyContinue
  $kind = if ($item) { (Get-Item -LiteralPath $path).GetValueKind($name).ToString() } else { $null }
  $list += [pscustomobject]@{ Path = $id; Name = $name; Present = [bool]$item; Value = $(if ($item) { $item.$name }); Kind = $kind }
  New-Item -ItemType Directory -Force (Split-Path $valuesFile) | Out-Null
  ConvertTo-Json -InputObject $list -Depth 3 | Set-Content -Encoding UTF8 $valuesFile
}
function Set-Value($path, $name, $value, $kind = 'DWord', $id = $path) {
  Save-Value $path $name $id
  if (-not (Test-Path -LiteralPath $path)) { New-Item -Force -Path $path | Out-Null }
  New-ItemProperty -Force -LiteralPath $path -Name $name -Value $value -PropertyType $kind | Out-Null
}
# Set-Value in every user's hive (Default included, so new users get it too).
function Set-UserValue($sub, $name, $value, $kind = 'DWord') {
  ForEach-UserHive { param($key, $user) Set-Value "Registry::$($key -replace '^HKU\\', 'HKEY_USERS\')\$sub" $name $value $kind "USER:$user\$sub" }
}


foreach ($m in @('backup') + $Modules) {
  . (Get-File "$BaseUrl/modules/$m.ps1" "$Tmp\$m.ps1")
}

# Saved for the update: the same choices next time, the versions from git.
[pscustomobject]@{ Profile = $Setup; Name = $Name; Uppgift = $Uppgift; OlaServer = $OlaServer; OlaEvent = $OlaEvent; BaseUrl = $BaseUrl; ReleaseUrl = $ReleaseUrl } |
  ConvertTo-Json | Set-Content -Encoding UTF8 "$Data\profile.json"

Step 'Check'
$ok = $true
foreach ($c in $Checks) {
  $text, $pass = & $c
  Write-Host ('{0,-8} {1}' -f $(if ($pass) { 'ok' } else { 'FAILED' }), $text); if (-not $pass) { $ok = $false }
}
$label = if ($Name) { $Name } else { $env:COMPUTERNAME }
Write-Host $(if ($ok) { "`nPASS $label ($Setup)" } else { "`nFAILED $label ($Setup) - see $Data\install.log" }) -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
Stop-Transcript | Out-Null
if ($ok -and $Name -and $env:COMPUTERNAME -ne $Name) {
  if ($Reboot) { Restart-Computer -Force } else { Write-Host 'Restart the laptop to use the new name.' }
}
if (-not $ok) { exit 1 }
