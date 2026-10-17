# desktop.ps1 - a clean desktop: launch icons and a TOOLS folder only (no Recycle Bin; scripts that are not event
# software move into TOOLS; the program folders the O-Ringen .bat files start from are hidden), in rows along the top.
Step 'Clean desktop, icons in a row'
$tools = "$env:PUBLIC\Desktop\TOOLS"; New-Item -ItemType Directory -Force $tools | Out-Null
Get-File "$BaseUrl/files/rensa-profil.ps1" "$Data\rensa-profil.ps1" | Out-Null   # "Rensa profil" in TOOLS
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut("$tools\Rensa profil.lnk")
$sc.TargetPath = 'powershell.exe'; $sc.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\rensa-profil.ps1`""
$sc.IconLocation = "$env:windir\System32\shell32.dll,31"; $sc.Description = 'Empty browser data, Downloads, recent files, temp and the Recycle Bin of this user'; $sc.Save()
Set-UserValue 'Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' '{645FF040-5081-101B-9F08-00AA002F954E}' 1   # Recycle Bin
$movesFile = "$Data\restore\moves.json"
$moves = @(Read-JsonFile $movesFile)
foreach ($d in Get-ChildItem C:\Users -Directory | Where-Object Name -ne 'Public' | ForEach-Object { "$($_.FullName)\Desktop" } | Where-Object { Test-Path $_ }) {
  # Web shortcuts (.url, Edge with an address) are on the Edge start page now: they move to Skrivbord-arkiv.
  foreach ($f in Get-ChildItem $d -File | Where-Object { $_.Extension -eq '.url' -or ($_.Extension -eq '.lnk' -and (New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName).TargetPath -like '*msedge.exe') }) {
    $arc = "$(Split-Path $d)\Skrivbord-arkiv"; New-Item -ItemType Directory -Force $arc | Out-Null
    Move-Item -Force $f.FullName "$arc\$($f.Name)"; $moves += [pscustomobject]@{ From = $f.FullName; To = "$arc\$($f.Name)"; Hidden = $false }
    Write-Host "web shortcut $($f.Name) moved to Skrivbord-arkiv (on the start page)"
  }
  foreach ($f in Get-ChildItem $d -File -Filter *.ps1) {   # scripts are tools, not event software
    Move-Item -Force $f.FullName "$tools\$($f.Name)"; $moves += [pscustomobject]@{ From = $f.FullName; To = "$tools\$($f.Name)"; Hidden = $false }
    Write-Host "moved $($f.Name) to TOOLS"
  }
  foreach ($bat in Get-ChildItem $d -File | Where-Object Extension -in '.bat', '.cmd') {
    foreach ($m in Select-String -Path $bat.FullName -Pattern '^\s*cd\s+"?([^"\\/]+)"?\s*$') {   # "cd OLA-Klient": the program folder
      $dir = Get-Item "$d\$($m.Matches[0].Groups[1].Value)" -Force -ErrorAction SilentlyContinue
      if ($dir -and $dir.PSIsContainer -and -not ($dir.Attributes -band [IO.FileAttributes]::Hidden)) {
        $dir.Attributes = $dir.Attributes -bor [IO.FileAttributes]::Hidden; $moves += [pscustomobject]@{ From = $dir.FullName; To = $null; Hidden = $true }
        Write-Host "hid $($dir.Name) (started by $($bat.Name))"
      }
    }
  }
}
# -KeepOnDesktop deltagarservice: on that laptop everything else on the users' desktops is old history and moves to
# C:\Users\<user>\Skrivbord-arkiv (not deleted; restore.ps1 puts it back).
if ($KeepOnDesktop) {
  $keep = @($KeepOnDesktop | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) + 'TOOLS', 'desktop.ini'
  foreach ($u in Get-ChildItem C:\Users -Directory | Where-Object Name -ne 'Public') {
    $d = "$($u.FullName)\Desktop"; if (-not (Test-Path $d)) { continue }
    $arc = "$($u.FullName)\Skrivbord-arkiv"
    foreach ($f in Get-ChildItem $d -Force | Where-Object { $_.Name -notin $keep -and -not ($_.Attributes -band [IO.FileAttributes]::Hidden) }) {
      New-Item -ItemType Directory -Force $arc | Out-Null
      Move-Item -Force $f.FullName "$arc\$($f.Name)"; $moves += [pscustomobject]@{ From = $f.FullName; To = "$arc\$($f.Name)"; Hidden = $false }
      Write-Host "archived $($f.Name) ($($u.Name))"
    }
  }
}
# -EmptyDownloadsAndTrash: an old laptop's Downloads and Recycle Bins are emptied for every user (cannot be undone).
if ($EmptyDownloadsAndTrash) {
  foreach ($u in Get-ChildItem C:\Users -Directory | Where-Object Name -ne 'Public') {
    Get-ChildItem "$($u.FullName)\Downloads" -Force -ErrorAction SilentlyContinue | Where-Object Name -ne 'desktop.ini' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }
  Get-ChildItem 'C:\$Recycle.Bin' -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object { Get-ChildItem $_.FullName -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
  Write-Host 'Downloads and Recycle Bins emptied'
}
Write-JsonFile @($moves) $movesFile

Get-File "$BaseUrl/files/desktop-row.ps1" "$Data\desktop-row.ps1" | Out-Null
$act = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\desktop-row.ps1`""
Register-ScheduledTask -Force -TaskName '10mila desktop row' -Action $act -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
  -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) `
  -Principal (New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545') | Out-Null
Start-ScheduledTask -TaskName '10mila desktop row'
Add-Check { @('clean desktop (TOOLS, no Recycle Bin), icons in a row at every logon', ((Test-Path $tools) -and [bool](Get-ScheduledTask -TaskName '10mila desktop row' -ErrorAction SilentlyContinue))) }
