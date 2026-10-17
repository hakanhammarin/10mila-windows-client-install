# libreoffice.ps1 - LibreOffice (O-Ringen deltagarservice), silent MSI, Swedish menus, no update checks, no desktop icon.
Step 'LibreOffice'
$lo = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName -like 'LibreOffice*' | Where-Object DisplayName -notlike '*Help*')
if ($lo | Where-Object { [version]$_.DisplayVersion -ge [version]$LibreOfficeVersion }) { Write-Host "LibreOffice $($lo[0].DisplayVersion) already installed" }
else {   # a newer MSI replaces an older LibreOffice by itself (same upgrade code across versions)
  $msi = Get-File "https://download.documentfoundation.org/libreoffice/stable/$LibreOfficeVersion/win/x86_64/LibreOffice_${LibreOfficeVersion}_Win_x86-64.msi" "$Tmp\libreoffice.msi"
  $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$msi`" /qn /norestart ALLUSERS=1 CREATEDESKTOPLINK=0 ISCHECKFORPRODUCTUPDATES=0 RebootYesNo=No UI_LANGS=sv /l*v `"$Data\libreoffice-msi.log`""
  if ($p.ExitCode -notin 0, 3010) { throw "LibreOffice msi failed: exit $($p.ExitCode), see $Data\libreoffice-msi.log" }
  Remove-Item $msi -ErrorAction SilentlyContinue
}
Add-Check { $v = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName -like 'LibreOffice*' | Where-Object DisplayName -notlike '*Help*' | Select-Object -First 1).DisplayVersion
  @("LibreOffice $v", ($v -and [version]$v -ge [version]$LibreOfficeVersion -and (Test-Path "$env:ProgramFiles\LibreOffice\program\soffice.exe"))) }
