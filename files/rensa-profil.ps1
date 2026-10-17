# rensa-profil.ps1 - "Rensa profil" in TOOLS: empties this user's traces between shifts: browser history, cookies and cache
# (Edge, Chrome, Firefox), Downloads, recent files, temp files and the Recycle Bin. The desktop and Documents are kept.
Add-Type -AssemblyName PresentationFramework
$what = "Rensa profilen f$([char]0xF6)r $env:USERNAME?`n`nWebbl$([char]0xE4)sare (historik, kakor, cache), H$([char]0xE4)mtade filer, senaste filer, temp och papperskorgen.`nSkrivbordet och Dokument f$([char]0xF6)rblir."
if ([Windows.MessageBox]::Show($what, 'Rensa profil', 'OKCancel', 'Warning') -ne 'OK') { return }
Get-Process msedge, chrome, firefox -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 2
$la = $env:LOCALAPPDATA; $ra = $env:APPDATA
$paths = @("$la\Microsoft\Edge\User Data", "$la\Google\Chrome\User Data") | Where-Object { Test-Path $_ } | ForEach-Object {
  Get-ChildItem $_ -Directory | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } | ForEach-Object {
    foreach ($n in 'History', 'History-journal', 'Cookies', 'Network\Cookies', 'Cache', 'Code Cache', 'Web Data', 'Login Data', 'Visited Links', 'Top Sites', 'Sessions') { "$($_.FullName)\$n" } } }
$paths += Get-ChildItem "$ra\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | ForEach-Object { "$($_.FullName)\places.sqlite", "$($_.FullName)\cookies.sqlite", "$($_.FullName)\cache2", "$($_.FullName)\sessionstore.jsonlz4" }
$paths += "$la\Mozilla\Firefox\Profiles", "$env:USERPROFILE\Downloads\*", "$ra\Microsoft\Windows\Recent\*", "$env:TEMP\*"
foreach ($p in $paths) { Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue }
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
[void][Windows.MessageBox]::Show("Profilen $([char]0xE4)r rensad.", 'Rensa profil')
