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
  [switch]$Reboot
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Profiles: which modules, in order. backup always runs first so restore.ps1 can undo the rest.
$profiles = @{
  '10mila'  = 'name', 'sportident', 'power', 'powerloss', 'ola', 'nummerlappar', 'receipt', 'firewall', 'wallpaper', 'desktop'
  'oringen' = 'power', 'receipt', 'firewall', 'wallpaper', 'desktop'
}
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
[pscustomobject]@{ Profile = $Setup; Modules = $Modules } | ConvertTo-Json | Set-Content "$Data\profile.json"

foreach ($m in @('backup') + $Modules) {
  . (Get-File "$BaseUrl/modules/$m.ps1" "$Tmp\$m.ps1")
}

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
