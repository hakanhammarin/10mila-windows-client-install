# reader.ps1 - Adobe Acrobat Reader on every laptop, the default for PDF (Edge prints PDFs badly), without the extras:
# no AI assistant, upsell, cloud services, sign-in, welcome screen, messages or updater.
Step 'Acrobat Reader, default for PDF'
$acro = 'C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe'   # the path acrobat_print_2.py uses
if (-not (Test-Path $acro)) {   # ~790 MB; no EULA flag: it is accepted at the first start
  Start-Process -Wait (Get-File $ReaderUrl "$Tmp\reader.exe") '/sAll /rs /msi /norestart ALLUSERS=1 DISABLEDESKTOPSHORTCUT=1'
  Remove-Item "$Tmp\reader.exe" -ErrorAction SilentlyContinue
}
# Policies (the 64-bit Reader reads the Acrobat DC policy key).
$fl = 'HKLM:\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'
foreach ($v in @(@($fl, 'bAcroSuppressUpsell', 1), @($fl, 'bEnableGentech', 0), @($fl, 'bUpdater', 0), @($fl, 'bToggleFTE', 1),
                 @($fl, 'bLimitPromptsFeatureKey', 1), @($fl, 'bEnableAV2Enterprise', 0), @($fl, 'bToggleShareFeedback', 1),
                 @("$fl\cServices", 'bToggleAdobeDocumentServices', 1), @("$fl\cServices", 'bToggleAdobeSign', 1),
                 @("$fl\cServices", 'bTogglePrefsSync', 1), @("$fl\cServices", 'bToggleWebConnectors', 1), @("$fl\cServices", 'bUpdater', 0),
                 @("$fl\cServices", 'bToggleNotifications', 1), @("$fl\cWelcomeScreen", 'bShowWelcomeScreen', 0),
                 @("$fl\cIPM", 'bShowMsgAtLaunch', 0), @("$fl\cIPM", 'bDontShowMsgWhenViewingDoc', 1))) {
  Set-Value $v[0] $v[1] $v[2]
}
Get-Service AdobeARMservice -ErrorAction SilentlyContinue | ForEach-Object { Stop-Service $_ -Force -ErrorAction SilentlyContinue; Set-Service $_.Name -StartupType Disabled }   # updater service
# Default for .pdf for every user, as policy (applied at each sign-in; Windows does not let a script set the user's choice).
$defaultApps = "$Data\default-apps.xml"
Set-Content -Encoding UTF8 $defaultApps @'
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".pdf" ProgId="Acrobat.Document.DC" ApplicationName="Adobe Acrobat" />
</DefaultAssociations>
'@
Set-Value 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' DefaultAssociationsConfiguration $defaultApps 'String'
Add-Check {
  $miss = @()
  if (-not (Test-Path $acro)) { $miss += 'Reader' }
  if ((Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -ErrorAction SilentlyContinue).DefaultAssociationsConfiguration -ne $defaultApps) { $miss += 'PDF default' }
  if ((Get-ItemProperty $fl -ErrorAction SilentlyContinue).bEnableGentech -ne 0) { $miss += 'policies' }
  @("Acrobat Reader, default for .pdf at sign-in, extras off$(if ($miss) { ' - missing: ' + ($miss -join ', ') })", ($miss.Count -eq 0)) }
