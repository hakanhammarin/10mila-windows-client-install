# receipt-watch.ps1 - runs from boot as SYSTEM (task "10mila receipt hello"): prints "Hello world" on the Star TSP100
# (TSP143, 72 mm receipt, length follows the text) at start when the printer is already plugged in, and every time it is plugged in.
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Drawing
$log = 'C:\ProgramData\10mila\receipt.log'
function Print-Hello {
  Start-Sleep 5   # let the spooler bring the USB queue online
  $q = Get-CimInstance Win32_Printer | Where-Object { $_.DriverName -like 'Star TSP1*' -and -not $_.WorkOffline } | Select-Object -First 1
  if (-not $q) { Add-Content $log "$(Get-Date -Format s) no Star printer online"; return }
  $doc = New-Object Drawing.Printing.PrintDocument
  $doc.PrinterSettings.PrinterName = $q.Name
  $doc.DocumentName = '10mila hello world'
  # 72 mm receipt paper (283 x 11822 hundredths of an inch, "72 mm x Receipt"): the driver cuts after the last line.
  $paper = $doc.PrinterSettings.PaperSizes | Where-Object { $_.Width -eq 283 -and $_.Height -gt 5000 } | Select-Object -First 1
  if ($paper) { $doc.DefaultPageSettings.PaperSize = $paper }
  $doc.DefaultPageSettings.Margins = New-Object Drawing.Printing.Margins 4, 4, 4, 4
  $doc.add_PrintPage({
    param($s, $e)
    $big = New-Object Drawing.Font 'Arial', 16, ([Drawing.FontStyle]::Bold)
    $small = New-Object Drawing.Font 'Arial', 9
    $y = 0
    foreach ($l in @(@('Hello world', $big), @("$env:COMPUTERNAME  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", $small), @($q.Name, $small))) {
      $e.Graphics.DrawString($l[0], $l[1], [Drawing.Brushes]::Black, 0, $y); $y += $l[1].GetHeight($e.Graphics) + 4
    }
    $e.Graphics.DrawString('.', $small, [Drawing.Brushes]::Black, 0, $y + 79)   # 20 mm feed (79/100 inch): the driver cuts after the last mark
    $e.HasMorePages = $false
  })
  try { $doc.Print(); Add-Content $log "$(Get-Date -Format s) printed on $($q.Name)" } catch { Add-Content $log "$(Get-Date -Format s) print failed: $_" }
}
$star = "SELECT * FROM __InstanceCreationEvent WITHIN 2 WHERE TargetInstance ISA 'Win32_PnPEntity' AND TargetInstance.PNPDeviceID LIKE 'USBPRINT\\STAR%'"
Register-CimIndicationEvent -Query $star -SourceIdentifier StarPlugged
if (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object InstanceId -like 'USBPRINT\STAR*') { Print-Hello }   # plugged in at boot
while ($true) {
  $ev = Wait-Event -SourceIdentifier StarPlugged
  Remove-Event -EventIdentifier $ev.EventIdentifier
  Print-Hello
}
