# autoplay.ps1 - nothing starts or pops up when a USB stick, card or phone is plugged in (AutoPlay and AutoRun off).
Step 'AutoPlay off'
$autoPol = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
Set-Value $autoPol NoDriveTypeAutoRun 255                                                  # all drive types
Set-Value $autoPol NoAutorun 1                                                             # no autorun.inf
Set-Value 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' NoAutoplayfornonVolume 1   # phones, cameras (MTP)
Set-UserValue 'Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' DisableAutoplay 1   # Settings > AutoPlay off
Add-Check { @('AutoPlay off for USB and other drives', ((Get-ItemProperty $autoPol -ErrorAction SilentlyContinue).NoDriveTypeAutoRun -eq 255)) }
