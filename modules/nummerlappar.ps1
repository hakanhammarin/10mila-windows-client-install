# nummerlappar.ps1 - bib printing station (PRINT-xx): OKI C542 PS, form 10mila, Python, Acrobat Reader, C:\bibs.
if ($me.Group -eq 'Nummerlappar') {
  Step 'Nummerlappar: printer, Python, Acrobat Reader, C:\bibs'
  $hosts = "$env:windir\System32\drivers\etc\hosts"
  $h = @(Get-Content $hosts | Where-Object { $_ -notmatch '\sOKIC542PS\s*$' }) + "$BibPrinterIp OKIC542PS"
  Set-Content -Encoding ASCII $hosts $h
  try {
    Get-File $OkiDriverUrl "$Tmp\oki.zip" | Out-Null
    Expand-Archive -Force "$Tmp\oki.zip" "$Tmp\oki"
    Get-ChildItem -Recurse "$Tmp\oki" -Filter *.inf | ForEach-Object { & pnputil.exe /add-driver $_.FullName /install | Out-Null }
    if (-not (Get-PrinterDriver 'OKI C542 PS' -ErrorAction SilentlyContinue)) { Add-PrinterDriver 'OKI C542 PS' }
    if (-not (Get-PrinterPort okic542 -ErrorAction SilentlyContinue)) { Add-PrinterPort -Name okic542 -PrinterHostAddress OKIC542PS }
    if (Get-Printer OKIC542PS -ErrorAction SilentlyContinue) { Set-Printer OKIC542PS -DriverName 'OKI C542 PS' -PortName okic542 }
    else { Add-Printer -Name OKIC542PS -DriverName 'OKI C542 PS' -PortName okic542 }
  } catch { Write-Host "OKI printer not installed: $_" -ForegroundColor Yellow }
  # Paper form "10mila" 160 x 225 mm (the bib), chosen in the driver's advanced settings.
  Add-Type -Namespace W -Name Spool -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct FORM_INFO_1 { public int Flags; public string Name; public int cx; public int cy; public int left; public int top; public int right; public int bottom; }
[StructLayout(LayoutKind.Sequential)] public struct PRINTER_DEFAULTS { public IntPtr Datatype; public IntPtr DevMode; public int DesiredAccess; }
[DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool OpenPrinter(string name, out IntPtr h, ref PRINTER_DEFAULTS d);
[DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool AddForm(IntPtr h, int level, ref FORM_INFO_1 f);
[DllImport("winspool.drv", SetLastError = true)] public static extern bool ClosePrinter(IntPtr h);
'@
  $f = New-Object W.Spool+FORM_INFO_1 -Property @{ Name = '10mila'; cx = 160000; cy = 225000; right = 160000; bottom = 225000 }   # 1/1000 mm
  $hp = [IntPtr]::Zero; $pd = New-Object W.Spool+PRINTER_DEFAULTS -Property @{ DesiredAccess = 1 }   # SERVER_ACCESS_ADMINISTER
  if ([W.Spool]::OpenPrinter("\\$env:COMPUTERNAME", [ref]$hp, [ref]$pd)) { [W.Spool]::AddForm($hp, 1, [ref]$f) | Out-Null; [W.Spool]::ClosePrinter($hp) | Out-Null }

  $py = 'C:\Program Files\Python312\python.exe'
  if (-not (Test-Path $py)) {
    Start-Process -Wait (Get-File $PythonUrl "$Tmp\python.exe") '/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_launcher=1 AssociateFiles=1'
  }
  & $py -m pip install --quiet --disable-pip-version-check --no-warn-script-location reportlab pypdf
  $acro = 'C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe'   # the path acrobat_print_2.py uses
  if (-not (Test-Path $acro)) {   # ~790 MB; no EULA flag: the operator accepts it at the first test print
    Start-Process -Wait (Get-File $ReaderUrl "$Tmp\reader.exe") '/sAll /rs /msi /norestart ALLUSERS=1 DISABLEDESKTOPSHORTCUT=1'
  }
  # Print station (C:\bibs, PDFs in C:\bibs\out_bibs are kept) and the generator (C:\bibs-prod).
  foreach ($r in @(@{ Repo = '10mila_bib_print_via_acrobat_reader_on_windows'; Dir = 'C:\bibs' }, @{ Repo = '10mila_bibs_prod'; Dir = 'C:\bibs-prod' })) {
    Get-File "https://codeload.github.com/hakanhammarin/$($r.Repo)/zip/HEAD" "$Tmp\$($r.Repo).zip" | Out-Null
    Remove-Item -Recurse -Force "$Tmp\$($r.Repo)" -ErrorAction SilentlyContinue
    Expand-Archive -Force "$Tmp\$($r.Repo).zip" "$Tmp\$($r.Repo)"
    $src = (Get-ChildItem "$Tmp\$($r.Repo)" -Directory | Select-Object -First 1).FullName
    New-Item -ItemType Directory -Force $r.Dir | Out-Null
    Get-ChildItem $src | Where-Object Name -notlike 'out_bibs*' | Copy-Item -Destination $r.Dir -Recurse -Force
  }
  New-Item -ItemType Directory -Force 'C:\bibs\out_bibs\printed' | Out-Null
  Copy-Item -Force 'C:\bibs\nummerlappar.cmd' "$env:PUBLIC\Desktop\nummerlappar.cmd"
}
if ($me.Group -eq 'Nummerlappar') {
  Add-Check { @('printer OKIC542PS with the OKI PS driver', ((Get-Printer OKIC542PS -ErrorAction SilentlyContinue).DriverName -eq 'OKI C542 PS')) }
  Add-Check { & $py -c 'import reportlab, pypdf'; @('Python with reportlab and pypdf', ($LASTEXITCODE -eq 0)) }
  Add-Check { @('Acrobat Reader', (Test-Path $acro)) }
  Add-Check { @('paper form 10mila (160 x 225 mm)', ($null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Forms' -ErrorAction SilentlyContinue).'10mila')) }
  Add-Check { @('C:\bibs and C:\bibs-prod', ((Test-Path 'C:\bibs\acrobat_print_2.py') -and (Test-Path 'C:\bibs-prod\bib_generator_optimized.py'))) }
}
