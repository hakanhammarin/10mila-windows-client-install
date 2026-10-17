# battery-log.ps1 - runs from boot as SYSTEM (task "10mila battery"): a battery test every time the laptop runs on battery.
# On battery: one row a minute in C:\ProgramData\10mila\battery\run-<start>.csv (time, %, mWh left, full and design mWh,
# SOH = full / design, volts, drain). When the charger is back, or at the next start after the battery ran out, the run
# is closed: runtime and charge used go to last.json, and the wallpaper shows them.
$ErrorActionPreference = 'Continue'
$dir = 'C:\ProgramData\10mila\battery'; New-Item -ItemType Directory -Force $dir | Out-Null
$runFile = "$dir\run.json"
function Save-Json($o, $path) { $o | ConvertTo-Json | Set-Content -Encoding UTF8 "$path.tmp"; Move-Item -Force "$path.tmp" $path }   # survives a power cut
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
# Runtime from full: drop in % over the minutes measured, scaled to 100 % (needs 10 min and 3 % drop to mean anything).
function Get-Estimate($rows) {
  if ($rows.Count -lt 2) { return $null }
  $min = ([datetime]$rows[-1].Time - [datetime]$rows[0].Time).TotalMinutes; $drop = [double]$rows[0].Percent - [double]$rows[-1].Percent
  if ($min -lt 10 -or $drop -lt 3) { return $null }
  [pscustomobject]@{ Measured = [math]::Round($min); Drop = $drop; FullMinutes = [math]::Round($min * 100 / $drop); LeftMinutes = [math]::Round($min * [double]$rows[-1].Percent / $drop) }
}
function Close-Run($how) {
  $run = try { Get-Content -Raw $runFile | ConvertFrom-Json } catch { $null }
  if (-not $run) { Remove-Item $runFile; return }   # damaged by the power cut that ended the run
  $rows = @(Import-Csv $run.File)
  if ($rows) {
    $first = $rows[0]; $last = $rows[-1]
    [pscustomobject]@{
      Start = $first.Time; End = $last.Time; Minutes = [math]::Round(([datetime]$last.Time - [datetime]$first.Time).TotalMinutes)
      FromPercent = $first.Percent; ToPercent = $last.Percent; SOH = $last.SOH; Volt = $last.Volt; Ended = $how; File = $run.File
      FullMinutes = (Get-Estimate $rows).FullMinutes
    } | ForEach-Object { Save-Json $_ "$dir\last.json" }
  }
  Remove-Item $runFile, "$dir\estimate.json" -ErrorAction SilentlyContinue
  if (Get-Command Update-Verdict -ErrorAction SilentlyContinue) { Update-Verdict }
  Start-ScheduledTask -TaskName '10mila wallpaper' -ErrorAction SilentlyContinue
}
# Back after the battery ran out (or a shutdown on battery): the open run ends at its last row.
if (Test-Path $runFile) { Close-Run 'battery ran out' }
# Verdict: DEAD when the evidence says the battery cannot carry the laptop, whatever its gauge claims.
#  - a battery test that ran out within 5 minutes, or
#  - 2 or more sudden power losses (Kernel-Power 41 with no crash code and no power button) since the last good test:
#    a laptop with a working battery does not lose power when the charger is pulled.
function Update-Verdict {
  $last = if (Test-Path "$dir\last.json") { Get-Content -Raw "$dir\last.json" | ConvertFrom-Json }
  $good = if ($last -and [int]$last.Minutes -ge 5) { [datetime]$last.End } else { (Get-Date).AddDays(-30) }
  $cuts = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $good } -ErrorAction SilentlyContinue |
    Where-Object { $_.Properties[0].Value -eq 0 -and $_.Properties[3].Value -eq 0 })   # BugcheckCode 0, PowerButtonTimestamp 0
  $short = $last -and $last.Ended -eq 'battery ran out' -and [int]$last.Minutes -lt 5
  $why = @()
  if ($short) { $why += "ran out after $($last.Minutes) min ($($last.FromPercent) %)" }
  if ($cuts.Count -ge 2) { $why += "$($cuts.Count) sudden power losses ($(($cuts | ForEach-Object { $_.TimeCreated.ToString('MM-dd HH:mm') }) -join ', '))" }
  Save-Json ([pscustomobject]@{ Dead = [bool]$why; Evidence = ($why -join '; '); PowerLosses = $cuts.Count; Checked = (Get-Date -Format s) }) "$dir\verdict.json"
}
Update-Verdict
Start-ScheduledTask -TaskName '10mila wallpaper' -ErrorAction SilentlyContinue
$lastRow = [datetime]::MinValue
while ($true) {
  $r = Read-Battery
  if (-not $r) { Start-Sleep 3600; continue }   # no battery in this machine
  if (-not $r.OnAC) {
    if (-not (Test-Path $runFile)) {
      $f = "$dir\run-$(Get-Date -Format yyyyMMdd-HHmmss).csv"
      Save-Json ([pscustomobject]@{ File = $f }) $runFile; $lastRow = [datetime]::MinValue
    }
    if (((Get-Date) - $lastRow).TotalSeconds -ge 59) {
      $r | Export-Csv -Append -NoTypeInformation -Encoding UTF8 (Get-Content -Raw $runFile | ConvertFrom-Json).File; $lastRow = Get-Date
      # Every 10 minutes on battery: the estimate so far, on the wallpaper.
      $rows = @(Import-Csv (Get-Content -Raw $runFile | ConvertFrom-Json).File)
      if ($rows.Count % 10 -eq 0 -and ($e = Get-Estimate $rows)) { Save-Json $e "$dir\estimate.json"; Start-ScheduledTask -TaskName '10mila wallpaper' -ErrorAction SilentlyContinue }
    }
  } elseif (Test-Path $runFile) {
    $r | Export-Csv -Append -NoTypeInformation -Encoding UTF8 (Get-Content -Raw $runFile | ConvertFrom-Json).File
    Close-Run 'charger back'
  }
  Start-Sleep 10   # notice unplug and plug-in quickly; a row is written once a minute
}
