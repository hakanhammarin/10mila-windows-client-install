# desktop.ps1 - a clean desktop: launch icons and a TOOLS folder only (no Recycle Bin; scripts that are not event
# software move into TOOLS; the program folders the O-Ringen .bat files start from are hidden), in rows along the top.
Step 'Clean desktop, icons in a row'
$tools = "$env:PUBLIC\Desktop\TOOLS"; New-Item -ItemType Directory -Force $tools | Out-Null
Set-UserValue 'Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' '{645FF040-5081-101B-9F08-00AA002F954E}' 1   # Recycle Bin
$movesFile = "$Data\restore\moves.json"
$moves = @(if (Test-Path $movesFile) { Get-Content -Raw $movesFile | ConvertFrom-Json })
foreach ($d in Get-ChildItem C:\Users -Directory | Where-Object Name -ne 'Public' | ForEach-Object { "$($_.FullName)\Desktop" } | Where-Object { Test-Path $_ }) {
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
New-Item -ItemType Directory -Force (Split-Path $movesFile) | Out-Null
ConvertTo-Json -InputObject @($moves) -Depth 3 | Set-Content -Encoding UTF8 $movesFile

Get-File "$BaseUrl/files/desktop-row.ps1" "$Data\desktop-row.ps1" | Out-Null
$act = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Data\desktop-row.ps1`""
Register-ScheduledTask -Force -TaskName '10mila desktop row' -Action $act -Trigger (New-ScheduledTaskTrigger -AtLogOn) `
  -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) `
  -Principal (New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545') | Out-Null
Start-ScheduledTask -TaskName '10mila desktop row'
Add-Check { @('clean desktop (TOOLS, no Recycle Bin), icons in a row at every logon', ((Test-Path $tools) -and [bool](Get-ScheduledTask -TaskName '10mila desktop row' -ErrorAction SilentlyContinue))) }
