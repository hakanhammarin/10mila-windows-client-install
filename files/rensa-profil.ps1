# rensa-profil.ps1 - "Rensa profil" in TOOLS: empties this user's traces between shifts and people:
# Microsoft accounts signed in to Windows apps and Edge (the user's own local account stays), browser history, cookies
# and cache (Edge, Chrome, Firefox), Downloads, recent files, temp files and the Recycle Bin. Desktop and Documents stay.
# -Quiet: no questions (for a script).
param([switch]$Quiet)
Add-Type -AssemblyName PresentationFramework
$what = "Rensa profilen f$([char]0xF6)r $env:USERNAME?`n`nMicrosoft-konton i Windows och Edge, webbl$([char]0xE4)sare (historik, kakor, cache), H$([char]0xE4)mtade filer, senaste filer, temp och papperskorgen.`nSkrivbordet och Dokument f$([char]0xF6)rblir."
if (-not $Quiet -and [Windows.MessageBox]::Show($what, 'Rensa profil', 'OKCancel', 'Warning') -ne 'OK') { return }
Get-Process msedge, chrome, firefox, OneDrive, Microsoft.AAD.BrokerPlugin -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
$la = $env:LOCALAPPDATA; $ra = $env:APPDATA
# Microsoft accounts added under Settings > Accounts (used by apps, Store, Office) and their tokens: Windows rebuilds the keys empty.
$paths = @("$la\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker\Accounts\*", "$la\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker\Cache\*",
           "$la\Microsoft\TokenBroker\Cache\*", "$la\Microsoft\IdentityCache\*", "$la\Microsoft\OneAuth\*")
Remove-Item -Recurse -Force 'HKCU:\Software\Microsoft\IdentityCRL\UserExtendedProperties', 'HKCU:\Software\Microsoft\IdentityCRL\Immersive\production\Token', 'HKCU:\Software\Microsoft\IdentityCRL\KeyCache' -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force 'HKCU:\Software\Microsoft\Office\16.0\Common\Identity\Identities' -ErrorAction SilentlyContinue
# Edge and Chrome: the whole profile goes (that is also the account signed in to the browser); Firefox: history, cookies, cache.
$paths += "$la\Microsoft\Edge\User Data", "$la\Google\Chrome\User Data"
$paths += Get-ChildItem "$ra\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FullName)\places.sqlite", "$($_.FullName)\cookies.sqlite", "$($_.FullName)\cache2", "$($_.FullName)\sessionstore.jsonlz4" }
$paths += "$la\Mozilla\Firefox\Profiles", "$env:USERPROFILE\Downloads\*", "$ra\Microsoft\Windows\Recent\*", "$env:TEMP\*"
foreach ($p in $paths) { Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue }
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
if (-not $Quiet) { [void][Windows.MessageBox]::Show("Profilen $([char]0xE4)r rensad. Logga ut och in f$([char]0xF6)r att Windows ska gl$([char]0xF6)mma kontot helt.", 'Rensa profil') }
$left = @(Get-ChildItem 'HKCU:\Software\Microsoft\IdentityCRL\UserExtendedProperties' -ErrorAction SilentlyContinue).Count + @(Get-ChildItem "$la\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker\Accounts" -ErrorAction SilentlyContinue).Count
Write-Host $(if ($left) { "FAILED: $left Microsoft account entries left" } else { 'PASS profile cleared' })
