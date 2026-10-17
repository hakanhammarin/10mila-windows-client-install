# taskbar.ps1 - the taskbar holds only the event programs (the launch icons on the desktop) and no Search, Task view,
# Widgets, Chat, Copilot or news buttons. The notification area (tray icons) is left exactly as it is.
Step 'Taskbar: event programs only'
$menu = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\10MILA'   # taskbar pins must point into the Start menu
Remove-Item -Recurse -Force $menu -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $menu | Out-Null
$sh = New-Object -ComObject WScript.Shell
$desks = @("$env:PUBLIC\Desktop") + @(Get-ChildItem C:\Users -Directory | Where-Object Name -ne 'Public' | ForEach-Object { "$($_.FullName)\Desktop" } | Where-Object { Test-Path $_ })
$pins = foreach ($f in $desks | ForEach-Object { Get-ChildItem $_ -File -ErrorAction SilentlyContinue } | Where-Object { $_.Extension -in '.lnk', '.bat', '.cmd' -and $_.BaseName -ne 'Microsoft Edge' }) {   # Edge gets its own button below
  $to = "$menu\$($f.BaseName).lnk"
  # The taskbar pins only programs, not .bat/.cmd files: those are started through cmd.exe, which can be pinned.
  if ($f.Extension -eq '.lnk') { $src = $sh.CreateShortcut($f.FullName); $target = $src.TargetPath; $wd = $src.WorkingDirectory; $icon = $src.IconLocation; $arg = $src.Arguments }
  else { $target = $f.FullName; $wd = $f.DirectoryName; $icon = "$env:windir\System32\shell32.dll,24"; $arg = '' }
  if (-not $icon -or $icon -match '^,') { $jw = Join-Path (Split-Path $target) 'javaw.exe'; $icon = if (Test-Path $jw) { "$jw,0" } else { "$env:windir\System32\shell32.dll,24" } }   # OLA's java icon
  $sc = $sh.CreateShortcut($to); $sc.WorkingDirectory = $wd; $sc.WindowStyle = 7; $sc.IconLocation = $icon
  if ($target -match '\.(bat|cmd)$') { $sc.TargetPath = $env:ComSpec; $sc.Arguments = "/c `"`"$target`" $arg`"" } else { $sc.TargetPath = $target; $sc.Arguments = $arg }
  $sc.Save()
  $to
}
# Edge with the start page: Edge ignores home page and start page policies on laptops outside a domain, so the taskbar
# button opens the page itself.
if (Test-Path "$Data\start\index.html") {
  $sc = $sh.CreateShortcut("$menu\Edge.lnk"); $sc.TargetPath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
  $sc.Arguments = '"file:///' + ("$Data\start\index.html" -replace '\\', '/') + '"'; $sc.Save(); $pins = @($pins) + "$menu\Edge.lnk"
}
$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
$(($pins | ForEach-Object { "        <taskbar:DesktopApp DesktopApplicationLinkPath=`"$_`" />" }) -join "`r`n")
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@
Set-Content -Encoding UTF8 "$Data\taskbar-layout.xml" $xml
# As machine policy: applied at every sign-in, for every user. The file has no Start section, so Start stays as it is.
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
Set-Value $pol StartLayoutFile "$Data\taskbar-layout.xml" 'ExpandString'
Set-Value $pol LockedStartLayout 1
# Buttons; a key Windows protects on this version is skipped (it is not there to show anyway).
foreach ($v in @(@($pol, 'HideSCAMeetNow', 1),                                        # Windows 10 Meet Now
                 @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds', 'EnableFeeds', 0),    # Windows 10 news and interests
                 @('HKLM:\SOFTWARE\Policies\Microsoft\Dsh', 'AllowNewsAndInterests', 0),             # Windows 11 widgets
                 @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat', 'ChatIcon', 3),        # Windows 11 chat
                 @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search', 'SearchOnTaskbarMode', 0))) {
  try { Set-Value $v[0] $v[1] $v[2] } catch { Write-Host "skipped $($v[1]): $($_.Exception.Message)" }
}
$adv = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-UserValue $adv ShowTaskViewButton 0
Set-UserValue $adv ShowCortanaButton 0
Set-UserValue $adv ShowCopilotButton 0
Set-UserValue 'Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 0
# Explorer reads it at start: restart it in each signed-in session, then put the desktop icons back in their row.
$act = New-ScheduledTaskAction -Execute cmd.exe -Argument '/c taskkill /f /im explorer.exe & start explorer.exe'
Register-ScheduledTask -Force -TaskName '10mila explorer restart' -Action $act -Principal (New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545') | Out-Null
Start-ScheduledTask -TaskName '10mila explorer restart'; Start-Sleep 6
Unregister-ScheduledTask -TaskName '10mila explorer restart' -Confirm:$false
if (Get-ScheduledTask -TaskName '10mila desktop row' -ErrorAction SilentlyContinue) { Start-ScheduledTask -TaskName '10mila desktop row' }
Write-Host "pinned: $((Get-ChildItem $menu).BaseName -join ', ')"
Add-Check { @("taskbar: $((Get-ChildItem $menu -ErrorAction SilentlyContinue).Count) event programs, no extra buttons", ((Get-ItemProperty $pol -ErrorAction SilentlyContinue).StartLayoutFile -eq "$Data\taskbar-layout.xml")) }
