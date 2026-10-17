# nummerlappar.ps1 - bib printing station (PRINT-xx): OKI C542 PS with paper "10mila bib", Python, Acrobat Reader, C:\bibs.
if ($me.Group -eq 'Nummerlappar') {
  Step 'Nummerlappar: printer, Python, Acrobat Reader, C:\bibs'
  $hosts = "$env:windir\System32\drivers\etc\hosts"
  $h = @(Get-Content $hosts | Where-Object { $_ -notmatch '\sOKIC542PS\s*$' }) + "$BibPrinterIp OKIC542PS"
  foreach ($try in 1..5) { try { Set-Content -Encoding ASCII $hosts $h -ErrorAction Stop; break } catch { if ($try -eq 5) { throw }; Start-Sleep 2 } }   # a virus scan can hold the file a moment
  try {
    Get-File $OkiDriverUrl "$Tmp\oki.zip" | Out-Null
    Expand-Archive -Force "$Tmp\oki.zip" "$Tmp\oki"
    Get-ChildItem -Recurse "$Tmp\oki" -Filter *.inf | ForEach-Object { & pnputil.exe /add-driver $_.FullName /install | Out-Null }
    if (-not (Get-PrinterDriver 'OKI C542 PS' -ErrorAction SilentlyContinue)) { Add-PrinterDriver 'OKI C542 PS' }
    if (-not (Get-PrinterPort okic542 -ErrorAction SilentlyContinue)) { Add-PrinterPort -Name okic542 -PrinterHostAddress OKIC542PS }
    if (Get-Printer OKIC542PS -ErrorAction SilentlyContinue) { Set-Printer OKIC542PS -DriverName 'OKI C542 PS' -PortName okic542 }
    else { Add-Printer -Name OKIC542PS -DriverName 'OKI C542 PS' -PortName okic542 }
  } catch { Write-Host "OKI printer not installed: $_" -ForegroundColor Yellow }
  # Paper "10mila bib": 225 x 160 mm printed landscape, fed like A5 with the short (160 mm) edge first, so the form is 160 wide, 225 long.
  Add-Type -Namespace W -Name Spool -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] public struct FORM_INFO_1 { public int Flags; public string Name; public int cx; public int cy; public int left; public int top; public int right; public int bottom; }
[StructLayout(LayoutKind.Sequential)] public struct PRINTER_DEFAULTS { public IntPtr Datatype; public IntPtr DevMode; public int DesiredAccess; }
[DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool OpenPrinter(string name, out IntPtr h, ref PRINTER_DEFAULTS d);
[DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool AddForm(IntPtr h, int level, ref FORM_INFO_1 f);
[DllImport("winspool.drv", SetLastError = true)] public static extern bool ClosePrinter(IntPtr h);
[DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool DeleteForm(IntPtr h, string name);
'@
  $f = New-Object W.Spool+FORM_INFO_1 -Property @{ Name = '10mila bib'; cx = 160000; cy = 225000; right = 160000; bottom = 225000 }   # 1/1000 mm
  $hp = [IntPtr]::Zero; $pd = New-Object W.Spool+PRINTER_DEFAULTS -Property @{ DesiredAccess = 1 }   # SERVER_ACCESS_ADMINISTER
  if ([W.Spool]::OpenPrinter("\\$env:COMPUTERNAME", [ref]$hp, [ref]$pd)) { [W.Spool]::DeleteForm($hp, '10mila') | Out-Null; [W.Spool]::AddForm($hp, 1, [ref]$f) | Out-Null; [W.Spool]::ClosePrinter($hp) | Out-Null }   # '10mila': the first name
  # Default for the printer: that paper, landscape (Acrobat and the driver start from it). The form is a driver option
  # (ns0000:UserFormNNN) that only the print ticket XML can name, so it is copied from the printer's capabilities.
  if (Get-Printer OKIC542PS -ErrorAction SilentlyContinue) {
    Add-Type -AssemblyName System.Printing, ReachFramework
    $q = New-Object System.Printing.PrintQueue -ArgumentList (New-Object System.Printing.LocalPrintServer), 'OKIC542PS', ([System.Printing.PrintSystemDesiredAccess]::AdministratePrinter)
    $ns = @{ psf = 'http://schemas.microsoft.com/windows/2003/08/printing/printschemaframework' }
    $capx = New-Object Xml.XmlDocument; $capx.Load($q.GetPrintCapabilitiesAsXml())
    $opt = (Select-Xml -Xml $capx -Namespace $ns -XPath "//psf:Feature[@name='psk:PageMediaSize']/psf:Option" | Where-Object { ($_.Node.Property | Where-Object name -eq 'psk:DisplayName').Value.'#text' -eq '10mila bib' } | Select-Object -First 1).Node
    if ($opt) {
      $prefix = $opt.name.Split(':')[0]
      $tk = New-Object Xml.XmlDocument; $tk.Load($q.DefaultPrintTicket.GetXmlStream())
      if (-not $tk.DocumentElement.GetNamespaceOfPrefix($prefix)) { $tk.DocumentElement.SetAttribute("xmlns:$prefix", $capx.DocumentElement.GetNamespaceOfPrefix($prefix)) }
      $new = $tk.ImportNode($opt, $true); foreach ($pr in @($new.Property)) { [void]$new.RemoveChild($pr) }; $new.RemoveAttribute('constrained')   # a ticket option has only a name
      $feat = (Select-Xml -Xml $tk -Namespace $ns -XPath "//psf:Feature[@name='psk:PageMediaSize']").Node; [void]$feat.ReplaceChild($new, $feat.Option)
      $ms = New-Object IO.MemoryStream; $tk.Save($ms); $ms.Position = 0
      $want = New-Object System.Printing.PrintTicket -ArgumentList $ms; $want.PageOrientation = [System.Printing.PageOrientation]::Landscape
      $q.DefaultPrintTicket = $q.MergeAndValidatePrintTicket($q.DefaultPrintTicket, $want).ValidatedPrintTicket; $q.Commit()
    } else { Write-Host 'the driver does not list the paper "10mila bib" yet' -ForegroundColor Yellow }
  }

  $py = 'C:\Program Files\Python312\python.exe'
  if (-not (Test-Path $py)) {
    Start-Process -Wait (Get-File $PythonUrl "$Tmp\python.exe") '/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_launcher=1 AssociateFiles=1'
  }
  & $py -m pip install --quiet --disable-pip-version-check --no-warn-script-location reportlab pypdf
  $acro = 'C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe'   # installed by the reader module
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
  # Descending order (the OKI stacks face down): until the bib repo has it, change the one loop line here.
  # ponytail: text patch; drop it when 10mila_bib_print_via_acrobat_reader_on_windows prints descending itself.
  $ap = 'C:\bibs\acrobat_print_2.py'; $code = [IO.File]::ReadAllText($ap)
  $code = $code.Replace('for i in range(start_nr, start_nr + antal):', 'for i in range(start_nr + antal - 1, start_nr - 1, -1):   # descending')
  [IO.File]::WriteAllText($ap, $code)
  Copy-Item -Force 'C:\bibs\nummerlappar.cmd' "$env:PUBLIC\Desktop\nummerlappar.cmd"
}
if ($me.Group -eq 'Nummerlappar') {
  Add-Check { @('printer OKIC542PS with the OKI PS driver', ((Get-Printer OKIC542PS -ErrorAction SilentlyContinue).DriverName -eq 'OKI C542 PS')) }
  Add-Check { & $py -c 'import reportlab, pypdf'; @('Python with reportlab and pypdf', ($LASTEXITCODE -eq 0)) }
  Add-Check { @('Acrobat Reader', (Test-Path $acro)) }
  Add-Check { [xml]$t = (Get-PrintConfiguration OKIC542PS -ErrorAction SilentlyContinue).PrintTicketXML
    $paper = ([regex]::Match($t.OuterXml, 'PageMediaSize"><psf:Option name="([^"]+)"')).Groups[1].Value
    @("OKIC542PS defaults to paper 10mila bib ($paper), landscape", (($paper -like '*UserForm*') -and ($t.OuterXml -match 'psk:Landscape'))) }
  Add-Check { @('bibs print in descending order', ((Get-Content 'C:\bibs\acrobat_print_2.py' -Raw) -match 'range\(start_nr \+ antal - 1, start_nr - 1, -1\)')) }
  Add-Check { @('C:\bibs and C:\bibs-prod', ((Test-Path 'C:\bibs\acrobat_print_2.py') -and (Test-Path 'C:\bibs-prod\bib_generator_optimized.py'))) }
}
