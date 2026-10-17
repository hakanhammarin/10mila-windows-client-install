# battery-log.ps1 - runs from boot as SYSTEM (task "10mila battery"): a battery test every time the laptop runs on battery.
# On battery: one row a minute in C:\ProgramData\10mila\battery\run-<start>.csv (time, %, mWh left, full and design mWh,
# SOH = full / design, volts, drain). When the charger is back, or at the next start after the battery ran out, the run
# is closed: runtime and charge used go to last.json, and the wallpaper shows them.
$ErrorActionPreference = 'Continue'
$dir = 'C:\ProgramData\10mila\battery'; New-Item -ItemType Directory -Force $dir | Out-Null
$runFile = "$dir\run.json"
# Many laptops do not publish BatteryStaticData: take the design capacity from the battery report once.
& powercfg.exe /batteryreport /xml /output "$dir\report.xml" | Out-Null
$designFromReport = [int]([regex]::Match((Get-Content "$dir\report.xml" -Raw -ErrorAction SilentlyContinue), '<DesignCapacity>(\d+)').Groups[1].Value)
function Read-Battery {
  $b = Get-CimInstance Win32_Battery | Select-Object -First 1
  if (-not $b) { return $null }
  $st = Get-CimInstance -Namespace root\wmi BatteryStatus -ErrorAction SilentlyContinue | Select-Object -First 1
  $full = (Get-CimInstance -Namespace root\wmi BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1).FullChargedCapacity
  $design = (Get-CimInstance -Namespace root\wmi BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1).DesignedCapacity
  if (-not $design) { $design = $script:designFromReport }
  [pscustomobject]@{
    Time = (Get-Date -Format s); OnAC = [bool]$st.PowerOnline; Percent = $b.EstimatedChargeRemaining; RemainingmWh = $st.RemainingCapacity
    FullmWh = $full; DesignmWh = $design; SOH = $(if ($design -gt 0) { [math]::Round(100 * $full / $design) }); Volt = [math]::Round($st.Voltage / 1000, 2); DrainmW = $st.DischargeRate
  }
}
function Close-Run($how) {
  $run = Get-Content -Raw $runFile | ConvertFrom-Json
  $rows = @(Import-Csv $run.File)
  if ($rows) {
    $first = $rows[0]; $last = $rows[-1]
    [pscustomobject]@{
      Start = $first.Time; End = $last.Time; Minutes = [math]::Round(([datetime]$last.Time - [datetime]$first.Time).TotalMinutes)
      FromPercent = $first.Percent; ToPercent = $last.Percent; SOH = $last.SOH; Volt = $last.Volt; Ended = $how; File = $run.File
    } | ConvertTo-Json | Set-Content -Encoding UTF8 "$dir\last.json"
  }
  Remove-Item $runFile
  Start-ScheduledTask -TaskName '10mila wallpaper' -ErrorAction SilentlyContinue
}
# Back after the battery ran out (or a shutdown on battery): the open run ends at its last row.
if (Test-Path $runFile) { Close-Run 'battery ran out' }
$lastRow = [datetime]::MinValue
while ($true) {
  $r = Read-Battery
  if (-not $r) { Start-Sleep 3600; continue }   # no battery in this machine
  if (-not $r.OnAC) {
    if (-not (Test-Path $runFile)) {
      $f = "$dir\run-$(Get-Date -Format yyyyMMdd-HHmmss).csv"
      [pscustomobject]@{ File = $f } | ConvertTo-Json | Set-Content $runFile; $lastRow = [datetime]::MinValue
    }
    if (((Get-Date) - $lastRow).TotalSeconds -ge 59) {
      $r | Export-Csv -Append -NoTypeInformation -Encoding UTF8 (Get-Content -Raw $runFile | ConvertFrom-Json).File; $lastRow = Get-Date
    }
  } elseif (Test-Path $runFile) {
    $r | Export-Csv -Append -NoTypeInformation -Encoding UTF8 (Get-Content -Raw $runFile | ConvertFrom-Json).File
    Close-Run 'charger back'
  }
  Start-Sleep 10   # notice unplug and plug-in quickly; a row is written once a minute
}
