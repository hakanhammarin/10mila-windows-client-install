# wallpaper.ps1 - BGInfo replacement, run at every logon in the user's session (task "10mila wallpaper").
# Draws Dator, Funktion and Uppgift in the upper right corner and sets it as this user's wallpaper.
# Style from C:\ProgramData\10mila\wallpaper.json: 10mila = plain light grey, oringen = O-Ringen banner (C:\bgi\o_ringen_cover.jpg).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
$cfg = Get-Content -Raw 'C:\ProgramData\10mila\wallpaper.json' | ConvertFrom-Json
$dator = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName   # the name after a pending rename
function First-Line($file) { if (Test-Path $file) { (Get-Content $file -Encoding Default | Where-Object { $_.Trim() } | Select-Object -First 1) } }
if ($cfg.Style -eq 'oringen') {   # same sources as Oringen.bgi: C:\bgi\Funktion.txt and Uppgift.txt (ANSI)
  $funktion = First-Line 'C:\bgi\Funktion.txt'; $uppgift = First-Line 'C:\bgi\Uppgift.txt'
} else {
  $c = Get-Content -Raw 'C:\ProgramData\10mila\client.json' -ErrorAction SilentlyContinue | ConvertFrom-Json
  $funktion = $c.Function; $uppgift = $c.Uppgift
}
Add-Type -Namespace W -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[W.Dpi]::SetProcessDPIAware() | Out-Null   # real pixels, not the scaled size at 125/150 %
# The bib printer's address as the hosts file has it (Nummerlappar laptops).
$oki = (Get-Content "$env:windir\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*([\d.]+)\s+OKIC542PS\s*$' } | Select-Object -Last 1) -replace '^\s*([\d.]+).*', '$1'
$fw = if (Test-Path 'C:\ProgramData\10mila\firewall-event.ps1') { "Brandv$([char]0xE4)gg event: " + $(if (Test-Path 'C:\ProgramData\10mila\firewall-event.json') { "P$([char]0xC5) (inget internet)" } else { 'AV' }) }
# Battery: the last test (runtime on battery) and the health now.
$bat = ''
$bl = 'C:\ProgramData\10mila\battery\last.json'
$soh = try { $f = (Get-CimInstance -Namespace root\wmi BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
  $d = (Get-CimInstance -Namespace root\wmi BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1).DesignedCapacity
  if (-not $d) { $d = [int]([regex]::Match((Get-Content 'C:\ProgramData\10mila\battery\report.xml' -Raw -ErrorAction SilentlyContinue), '<DesignCapacity>(\d+)').Groups[1].Value) }
  if ($d -gt 0) { [math]::Round(100 * $f / $d) } } catch { $null }
if (Test-Path $bl) {
  $t = Get-Content -Raw $bl | ConvertFrom-Json
  $dur = if ($t.Minutes -ge 60) { '{0} h {1} min' -f [math]::Floor($t.Minutes / 60), ($t.Minutes % 60) } else { "$($t.Minutes) min" }
  $bat = "Batteri: $dur ($($t.FromPercent) -> $($t.ToPercent) %$(if ($t.Ended -eq 'battery ran out') { ', tog slut' }))"
}
$sohLine = if ($soh) { "Batteri SOH: $soh %" }
$scr = [Windows.Forms.Screen]::PrimaryScreen.Bounds
$w = [Math]::Max($scr.Width, 800); $h = [Math]::Max($scr.Height, 600)
$bmp = New-Object Drawing.Bitmap $w, $h
$g = [Drawing.Graphics]::FromImage($bmp)
$g.TextRenderingHint = 'AntiAliasGridFit'; $g.InterpolationMode = 'HighQualityBicubic'
if ($cfg.Style -eq 'oringen' -and (Test-Path 'C:\bgi\o_ringen_cover.jpg')) {
  $img = [Drawing.Image]::FromFile('C:\bgi\o_ringen_cover.jpg')
  $g.Clear(([Drawing.Bitmap]$img).GetPixel(2, $img.Height - 2))   # the banner's own background colour
  $ih = [int]($img.Height * $w / $img.Width)
  $src = New-Object Drawing.Rectangle 3, 3, ($img.Width - 6), ($img.Height - 6)   # skip the jpg's light 1-2 px border
  $g.DrawImage($img, (New-Object Drawing.Rectangle 0, ([int](($h - $ih) / 2)), $w, $ih), $src, [Drawing.GraphicsUnit]::Pixel); $img.Dispose()
} else {
  $g.Clear([Drawing.Color]::FromArgb(190, 190, 190))   # light grey: icons stand out, not bright at night
}
$ink = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(30, 30, 30))
$fmt = New-Object Drawing.StringFormat; $fmt.Alignment = 'Far'
$big = New-Object Drawing.Font 'Arial', ([int]($h / 20)), ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
$small = New-Object Drawing.Font 'Arial', ([int]($h / 34)), ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$m = [int]($h / 40); $y = $m
foreach ($line in @(@("Dator: $dator", $big), @("Funktion: $funktion", $small), @("Uppgift: $uppgift", $small), @("Skrivare OKI: $oki", $small), @($fw, $small), @($bat, $small), @($sohLine, $small))) {
  if (-not "$($line[0])".Trim() -or $line[0] -match ':\s*$') { continue }   # empty value: leave the line out
  $g.DrawString($line[0], $line[1], $ink, [single]($w - $m), [single]$y, $fmt); $y += $line[1].Height * 1.15
}
if ($cfg.Style -ne 'oringen' -and (Test-Path 'C:\ProgramData\10mila\10mila-logo.png')) {   # 10MILA logo, lower right, above the taskbar
  $logo = [Drawing.Image]::FromFile('C:\ProgramData\10mila\10mila-logo.png')
  $lh = [int]($h / 4); $lw = [int]($logo.Width * $lh / $logo.Height)
  $g.DrawImage($logo, $w - $lw - $m * 2, $h - $lh - [int]($h / 12), $lw, $lh); $logo.Dispose()
}
$g.Dispose()
$out = Join-Path $env:LOCALAPPDATA '10mila-wallpaper.bmp'
$bmp.Save($out, [Drawing.Imaging.ImageFormat]::Bmp); $bmp.Dispose()
Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle '10'   # fill: also right after a resolution change
Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper '0'
Add-Type -Namespace W -Name Desk -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int SystemParametersInfo(int a, int b, string c, int d);'
[W.Desk]::SystemParametersInfo(20, 0, $out, 3) | Out-Null   # SPI_SETDESKWALLPAPER, update ini + broadcast
