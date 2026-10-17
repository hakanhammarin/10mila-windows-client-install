# powerloss.ps1 - PowerLoss agent at boot as SYSTEM, location = function.
Step 'PowerLoss agent'
$pl = 'C:\Program Files\10mila\PowerLoss'
New-Item -ItemType Directory -Force $pl | Out-Null
Get-ScheduledTask -TaskName '10mila PowerLoss' -ErrorAction SilentlyContinue | Stop-ScheduledTask
Get-Process powerloss-agent -ErrorAction SilentlyContinue | Stop-Process -Force
Get-File "$ReleaseUrl/powerloss-agent.exe" "$pl\powerloss-agent.exe" | Out-Null
[IO.File]::WriteAllText("$pl\settings.json", ([pscustomobject]@{ computer_name = $Name; location = $Function; port = 3000 } | ConvertTo-Json))  # UTF-8 without BOM for Go
# ponytail: a boot-time SYSTEM task instead of a Windows service; the agent has no service handler yet (monitoring owns it).
$act = New-ScheduledTaskAction -Execute "$pl\powerloss-agent.exe" -WorkingDirectory $pl
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Register-ScheduledTask -Force -TaskName '10mila PowerLoss' -Action $act -Settings $set -Trigger (New-ScheduledTaskTrigger -AtStartup) `
  -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest) | Out-Null
Get-NetFirewallRule -DisplayName '10mila PowerLoss' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName '10mila PowerLoss' -Group '10mila' -Direction Inbound -Program "$pl\powerloss-agent.exe" -Action Allow -Profile Any | Out-Null
Start-ScheduledTask -TaskName '10mila PowerLoss'
Add-Check { Start-Sleep 3; $st = try { Invoke-RestMethod -UseBasicParsing -TimeoutSec 5 http://127.0.0.1:3000/api/status } catch { $null }
  @("PowerLoss answers on :3000 (soc $($st.soc), charging $($st.is_charging))", ($null -ne $st)) }
