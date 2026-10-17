# name.ps1 - pick the computer name by function (computers.csv), rename, write client.json.
Step 'Computer name'
$list = Import-Csv (Get-File "$BaseUrl/computers.csv" "$Tmp\computers.csv") -Encoding UTF8 | ForEach-Object {
  $f = $_; 1..[int]$f.Count | ForEach-Object { [pscustomobject]@{ Group = $f.Group; Function = $f.Function; Name = '{0}-{1:D2}' -f $f.Prefix, $_ } }
}
if (-not $Name) {
  $funcs = @($list | Select-Object -ExpandProperty Function -Unique)
  for ($i = 0; $i -lt $funcs.Count; $i++) {
    $g = ($list | Where-Object Function -eq $funcs[$i] | Select-Object -First 1).Group
    Write-Host ('{0,3}. {1,-14} {2}' -f ($i + 1), $g, $funcs[$i])
  }
  $pick = $funcs[[int](Read-Host 'Function number') - 1]
  $names = @($list | Where-Object Function -eq $pick)
  for ($i = 0; $i -lt $names.Count; $i++) { Write-Host ('{0,3}. {1}' -f ($i + 1), $names[$i].Name) }
  $Name = $names[[int](Read-Host 'Computer number (check the label on the laptop)') - 1].Name
}
$me = $list | Where-Object Name -eq $Name.ToUpper()
if (-not $me) { throw "$Name is not in computers.csv" }
$Name = $me.Name; $Function = $me.Function
Write-Host "$Name  ($Function)"
Write-JsonFile ([pscustomobject]@{ Name = $Name; Function = $Function; Group = $me.Group; Uppgift = $Uppgift }) "$Data\client.json"
if ($env:COMPUTERNAME -ne $Name) { Rename-Computer -NewName $Name -Force -WarningAction SilentlyContinue }
Add-Check { $p = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
  @("computer name $p (now $env:COMPUTERNAME)", ($p -eq $Name)) }
