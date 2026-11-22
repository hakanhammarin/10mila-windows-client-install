# jaktstart.ps1 - chase start station (CHASE-xx): StarterClock (Tak-Soft's Store app 9WZDNCRFJ937, the start clock that
# reads the chase start list) and "Jaktstart startlistor" on the desktop, which fetches the start lists of Herrkavlen and
# Damkavlen from the operations menu on the OLA server (http://<server>:8096/jaktstart/<class>.csv, no PIN) into C:\Jaktstart.
# The crew laptops run Windows LTSC (no Store, no winget), so the app comes as package files ($StarterClockPackage and
# $StarterClockDeps) from the utility server on the LAN ($StarterClockUrl, http://UTIL_IP:8097/starterclock; search.sh copies
# them there from dist/ on the admin Mac). They are Tak-Soft's, so never in git or a public release (Håkan 2026-11-22).
# Provisioned for every user, also those not created yet.
# The old ClickOnce StarterClock (C:\Program Files (x86)\StarterClock, 2013) is removed.
if (-not $me -and $Function) { $me = [pscustomobject]@{ Group = $Function } }   # -Modules jaktstart -Function Jaktstart: no rename
if ($me.Group -eq 'Jaktstart') {
  Step 'Jaktstart: StarterClock and the start list download'
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  function Read-ZipXml($zip, $entry) {   # one XML file out of a package (appx/msix are zip files)
    $z = [IO.Compression.ZipFile]::OpenRead($zip)
    try { $e = $z.GetEntry($entry); if (-not $e) { return $null }; $r = New-Object IO.StreamReader($e.Open()); try { [xml]$r.ReadToEnd() } finally { $r.Close() } } finally { $z.Dispose() }
  }
  $scUrl = $StarterClockUrl.TrimEnd('/')
  $pkg = Get-File "$scUrl/$StarterClockPackage" "$Tmp\$StarterClockPackage"
  $deps = @($StarterClockDeps | ForEach-Object { $_ -split ',' } | Where-Object { $_ } | ForEach-Object { Get-File "$scUrl/$_" "$Tmp\$_" })
  # Name and app id from the manifest: a bundle names its packages, the app's own manifest has the Application Id.
  $app = $pkg; $bundle = Read-ZipXml $pkg 'AppxMetadata/AppxBundleManifest.xml'
  if ($bundle) {
    $inner = @($bundle.Bundle.Packages.Package | Where-Object { $_.Type -eq 'application' }) | Sort-Object { @('x64', 'neutral', 'x86').IndexOf($_.Architecture) } | Where-Object { $_.Architecture -in 'x64', 'neutral', 'x86' } | Select-Object -First 1
    if (-not $inner) { throw "StarterClock: no x64/x86 app in $StarterClockPackage" }
    $z = [IO.Compression.ZipFile]::OpenRead($pkg)
    try { $app = "$Tmp\sc-inner.appx"; [IO.Compression.ZipFileExtensions]::ExtractToFile($z.GetEntry($inner.FileName), $app, $true) } finally { $z.Dispose() }
  }
  $man = Read-ZipXml $app 'AppxManifest.xml'
  if (-not $man) { throw "StarterClock: no AppxManifest.xml in $StarterClockPackage" }
  $scName = $man.Package.Identity.Name; $scVersion = $man.Package.Identity.Version
  $appId = @($man.Package.Applications.Application)[0].Id
  $a = @{ Online = $true; PackagePath = $pkg; SkipLicense = $true }; if ($deps) { $a.DependencyPackagePath = $deps }
  Add-AppxProvisionedPackage @a | Out-Null   # every user, at their next sign-in; the same version again is a no-op
  $prov = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $scName | Select-Object -First 1
  if (-not $prov) { throw "StarterClock: $scName is not provisioned" }
  $scFamily = "$($prov.DisplayName)_$($prov.PublisherId)"
  # The old ClickOnce copy and its shortcut go; the new shortcut starts the Store app.
  Get-Process StartClockWP -ErrorAction SilentlyContinue | Stop-Process -Force -PassThru | Wait-Process -Timeout 15 -ErrorAction SilentlyContinue   # else the exe is still locked
  Remove-Item -Recurse -Force 'C:\Program Files (x86)\StarterClock' -ErrorAction SilentlyContinue
  $sh = New-Object -ComObject WScript.Shell
  $sc = $sh.CreateShortcut("$env:PUBLIC\Desktop\StarterClock.lnk")
  $sc.TargetPath = "$env:windir\explorer.exe"; $sc.Arguments = "shell:AppsFolder\$scFamily!$appId"; $sc.Description = "StarterClock $scVersion (Tak-Soft)"; $sc.Save()
  Write-Host "StarterClock $scName $scVersion provisioned for every user ($scFamily!$appId)"
  # The start list download: the servers in order, the first that answers wins (server01, then the others).
  New-Item -ItemType Directory -Force 'C:\Jaktstart' | Out-Null
  & icacls.exe 'C:\Jaktstart' /grant '*S-1-5-32-545:(OI)(CI)M' | Out-Null   # Users may write the lists
  Get-File "$BaseUrl/files/jaktstart-hamta.ps1" "$Data\jaktstart-hamta.ps1" | Out-Null
  $sc = $sh.CreateShortcut("$env:PUBLIC\Desktop\Jaktstart startlistor.lnk")
  $sc.TargetPath = 'powershell.exe'; $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Data\jaktstart-hamta.ps1`" -Servers $(@($ChaseServers) -join ',')"
  $sc.IconLocation = "$env:windir\System32\shell32.dll,122"; $sc.WorkingDirectory = 'C:\Jaktstart'
  $sc.Description = 'Fetch the chase start lists (Herrkavlen, Damkavlen) for StarterClock into C:\Jaktstart'; $sc.Save()
  # TOOLS: the same lists as a test, first start 5 minutes from now, to try StarterClock with the clocks in real time.
  New-Item -ItemType Directory -Force "$env:PUBLIC\Desktop\TOOLS" | Out-Null
  $sc = $sh.CreateShortcut("$env:PUBLIC\Desktop\TOOLS\Jaktstart testlistor (start om 5 min).lnk")
  $sc.TargetPath = 'powershell.exe'; $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Data\jaktstart-hamta.ps1`" -TestMinutes 5 -Servers $(@($ChaseServers) -join ',')"
  $sc.IconLocation = "$env:windir\System32\shell32.dll,122"; $sc.WorkingDirectory = 'C:\Jaktstart'; $sc.Save()
}
if ($me.Group -eq 'Jaktstart') {
  Add-Check { @("StarterClock $scVersion for every user, icon on the desktop", ([bool](Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $scName) -and
    ($sh.CreateShortcut("$env:PUBLIC\Desktop\StarterClock.lnk").Arguments -eq "shell:AppsFolder\$scFamily!$appId") -and -not (Test-Path 'C:\Program Files (x86)\StarterClock'))) }
  Add-Check { @('Jaktstart startlistor on the desktop (C:\Jaktstart)', ((Test-Path "$env:PUBLIC\Desktop\Jaktstart startlistor.lnk") -and (Test-Path "$Data\jaktstart-hamta.ps1"))) }
}
