# backup.ps1 - before the first change, save everything the modules change, for restore.ps1.
# Runs once: a later install keeps the first (original) snapshot.
$RestoreDir = "$Data\restore"
if (Test-Path "$RestoreDir\snapshot.json") { Add-Check { @("restore snapshot in $RestoreDir (kept)", $true) }; Write-Host "`n== Backup: kept the snapshot from $((Get-Content -Raw "$RestoreDir\snapshot.json" | ConvertFrom-Json).Taken)"; return }
Step 'Backup of the original settings'
New-Item -ItemType Directory -Force "$RestoreDir\reg" | Out-Null

# Registry keys the modules write: exported if present, recorded as absent otherwise (restore deletes them then).
$regs = New-Object Collections.Generic.List[object]
function Save-Key($key, $file, $root = '') {
  & cmd.exe /c "reg query `"$key`" >nul 2>&1"
  $present = $LASTEXITCODE -eq 0
  if ($present) { & cmd.exe /c "reg export `"$key`" `"$RestoreDir\reg\$file.reg`" /y >nul 2>&1" }
  $regs.Add([pscustomobject]@{ Key = $key; File = "$file.reg"; Present = $present; Root = $root })
}
Save-Key 'HKLM\SOFTWARE\Policies\Microsoft\Power' 'hklm-power-policy'
Save-Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP' 'hklm-personalizationcsp'
ForEach-UserHive {
  param($key, $user)
  foreach ($k in @(@('Control Panel\Desktop', 'desktop'), @('Software\Policies\Microsoft\Windows\Control Panel\Desktop', 'desktop-policy'),
                   @('Software\Microsoft\Windows\Shell\Bags\1\Desktop', 'icon-layout'))) {
    Save-Key "$key\$($k[0])" "user-$user-$($k[1])" $key   # Root: the hive path at export time, swapped on restore
  }
}

# Power scheme values that have no policy, hibernation, network adapters' power saving.
$scheme = [regex]::Match((& powercfg.exe /getactivescheme | Out-String), '[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}').Value
$values = foreach ($s in 'SUB_BUTTONS UIBUTTON_ACTION', 'SUB_PCIEXPRESS ASPM', 'SUB_VIDEO VIDEOADAPT', '2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226') {
  $q = & cmd.exe /c "powercfg /query $scheme $s 2>nul" | Out-String
  $hex = [regex]::Matches($q, ':\s*0x([0-9a-f]{8})') | ForEach-Object { [Convert]::ToInt32($_.Groups[1].Value, 16) }
  if ($hex.Count -ge 2) { [pscustomobject]@{ Setting = $s; AC = $hex[-2]; DC = $hex[-1] } }
}
# Policies\System holds UAC: only the one value we set is saved, never the whole key.
$idle = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue).InactivityTimeoutSecs
$hiber = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -ErrorAction SilentlyContinue).HibernateEnabled
$nics = @(Get-NetAdapter -Physical | Get-NetAdapterPowerManagement -ErrorAction SilentlyContinue | Where-Object AllowComputerToTurnOffDevice -eq 'Enabled' | ForEach-Object Name)

# Firewall policy, hosts, OLA settings, startup folders, desktops, OLA versions.
& netsh.exe advfirewall export "$RestoreDir\firewall.wfw" | Out-Null
Copy-Item "$env:windir\System32\drivers\etc\hosts" "$RestoreDir\hosts"
if (Test-Path 'C:\ProgramData\OLA6') { Copy-Item -Recurse -Force 'C:\ProgramData\OLA6' "$RestoreDir\OLA6" -Exclude db, log, backup }
$desktops = @("$env:PUBLIC\Desktop") + @(Get-ChildItem C:\Users -Directory | ForEach-Object { "$($_.FullName)\Desktop" } | Where-Object { Test-Path $_ }) | Select-Object -Unique
[pscustomobject]@{
  Taken        = (Get-Date -Format s)
  ComputerName = $env:COMPUTERNAME
  Registry     = $regs
  PowerScheme  = $scheme
  PowerValues  = @($values)
  Hibernate    = $hiber
  IdleLockSecs = $idle
  NicPowerSave = $nics
  OlaProducts  = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName -eq 'OLA 6' | ForEach-Object PSChildName)
  Desktop      = @($desktops | ForEach-Object { Get-ChildItem $_ -Force -ErrorAction SilentlyContinue | ForEach-Object FullName })
  Printers     = @(Get-Printer | ForEach-Object Name)
} | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 "$RestoreDir\snapshot.json"
Write-Host "saved to $RestoreDir"
Add-Check { @("restore snapshot in $RestoreDir", ((Test-Path "$RestoreDir\snapshot.json", "$RestoreDir\firewall.wfw", "$RestoreDir\hosts") -notcontains $false)) }
