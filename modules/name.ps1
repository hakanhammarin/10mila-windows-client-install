# name.ps1 - the computer name: pick the function (computers.csv), the name is the function's prefix and a random suffix
# (0-9, A-Z), e.g. READOUT-7K2P. PowerLoss reports name and function, so a power cut shows where it is at once.
# A laptop that already has a name of that function keeps it (updates do not rename it).
Step 'Computer name'
$funcs = @(Import-Csv (Get-File "$BaseUrl/computers.csv" "$Tmp\computers.csv") -Encoding UTF8)
$cur = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName   # incl. a pending rename
function Find-Function($n) { $funcs | Where-Object { $n -like "$($_.Prefix)-*" } | Sort-Object { $_.Prefix.Length } -Descending | Select-Object -First 1 }
if ($Name) { $me = Find-Function $Name.ToUpper(); if (-not $me) { $me = $funcs | Where-Object Function -eq $Name } }   # -Name READOUT-7K2P or -Name "Check IN"
elseif ($Function) { $me = $funcs | Where-Object Function -eq $Function }
else {
  for ($i = 0; $i -lt $funcs.Count; $i++) { Write-Host ('{0,3}. {1,-14} {2}' -f ($i + 1), $funcs[$i].Group, $funcs[$i].Function) }
  $me = $funcs[[int](Read-Host 'Function number') - 1]
}
if (-not $me) { throw "no function in computers.csv for '$Name$Function'" }
if ($Name -and ($Name.ToUpper() -like "$($me.Prefix)-*")) { $Name = $Name.ToUpper() }   # given in full
elseif ($cur -like "$($me.Prefix)-*") { $Name = $cur }                                   # already named for this function
else {
  $chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()
  $Name = "$($me.Prefix)-" + (-join (1..4 | ForEach-Object { $chars | Get-Random }))
}
$Function = $me.Function
Write-Host "$Name  ($Function)"
Write-JsonFile ([pscustomobject]@{ Name = $Name; Function = $Function; Group = $me.Group; Uppgift = $Uppgift }) "$Data\client.json"
if ($cur -ne $Name) { Rename-Computer -NewName $Name -Force -WarningAction SilentlyContinue }
Add-Check { $p = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
  @("computer name $p (now $env:COMPUTERNAME), function $Function", ($p -eq $Name)) }
