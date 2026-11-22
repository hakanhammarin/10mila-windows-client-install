# jaktstart-hamta.ps1 - "Jaktstart startlistor" on the desktop of a chase start station: fetches the StarterClock start
# lists of the chase classes from the operations menu (http://<server>:8096/jaktstart/<class>.csv, no PIN) into
# C:\Jaktstart. The servers are tried in order (server01 first); the first that answers wins. Then import the file in
# StarterClock. A list holds every team that has a chase start time; the wave start is left out.
param([string[]]$Servers = @('192.168.1.21'), [string[]]$Classes = @('herrkavlen', 'damkavlen'), [string]$Dir = 'C:\Jaktstart', [string]$Encoding = 'utf-8', [int]$TestMinutes = 0)
# -TestMinutes 1-30: a test file, first start that many minutes from now, the others moved by as much (TOOLS icon).
$Servers = @($Servers | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
New-Item -ItemType Directory -Force $Dir | Out-Null
$ok = $true
foreach ($c in $Classes) {
  $got = $false
  foreach ($s in $Servers) {
    $out = Join-Path $Dir "jaktstart-$c$(if ($TestMinutes) { '-test' }).csv"
    & curl.exe -fsS --max-time 10 -o "$out.tmp" "http://${s}:8096/jaktstart/$c.csv?enc=$Encoding$(if ($TestMinutes) { "&test=$TestMinutes" })"
    if ($LASTEXITCODE -eq 0) {
      Move-Item -Force "$out.tmp" $out
      $n = @(Get-Content $out | Where-Object { $_ }).Count
      Write-Host ("{0,-11} {1,4} teams  from {2}  -> {3}" -f $c, $n, $s, $out) -ForegroundColor Green
      $got = $true; break
    }
    Remove-Item "$out.tmp" -ErrorAction SilentlyContinue
  }
  if (-not $got) { Write-Host "${c}: no server answered ($($Servers -join ', '))" -ForegroundColor Red; $ok = $false }
}
Write-Host ''
Write-Host $(if ($ok) { 'Klart. Importera filen i StarterClock.' } else { 'Inte klart: se ovan.' })
Read-Host "Tryck Enter" | Out-Null
