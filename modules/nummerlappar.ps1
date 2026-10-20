# nummerlappar.ps1 - bib printing station (PRINT-xx): native bib printing in C:\bibs (Ghostscript, raw port 9100), OKI C542 PS
# with paper "10mila bib" for the spooler backend, Python, the generator in C:\bibs-prod.
if ($me.Group -eq 'Nummerlappar') {
  Step 'Nummerlappar: printer, Python, native bib printing in C:\bibs'
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
  # Print station C:\bibs: 10mila_bib_print_native_on_windows (Ghostscript to PostScript, raw to the printer on port 9100,
  # no Acrobat). The legacy Acrobat printing (acrobat_print_2.py and its settings) goes; the PDFs in out_bibs stay, and
  # a settings.py that is already the native one is kept (local printer choices). Generator: 10mila_bibs_prod in C:\bibs-prod.
  foreach ($old in 'acrobat_print_2.py', '__pycache__', 'Skrivarinst*.pdf') { Remove-Item -Recurse -Force "C:\bibs\$old" -ErrorAction SilentlyContinue }
  $keepSettings = (Test-Path 'C:\bibs\settings.py') -and (Select-String -Path 'C:\bibs\settings.py' -Pattern 'WIN_PRINT_BACKEND' -Quiet)
  foreach ($r in @(@{ Repo = '10mila_bib_print_native_on_windows'; Dir = 'C:\bibs' }, @{ Repo = '10mila_bibs_prod'; Dir = 'C:\bibs-prod' })) {
    Get-File "https://codeload.github.com/hakanhammarin/$($r.Repo)/zip/HEAD" "$Tmp\$($r.Repo).zip" | Out-Null
    Remove-Item -Recurse -Force "$Tmp\$($r.Repo)" -ErrorAction SilentlyContinue
    Expand-Archive -Force "$Tmp\$($r.Repo).zip" "$Tmp\$($r.Repo)"
    $src = (Get-ChildItem "$Tmp\$($r.Repo)" -Directory | Select-Object -First 1).FullName
    New-Item -ItemType Directory -Force $r.Dir | Out-Null
    Get-ChildItem $src | Where-Object { $_.Name -notlike 'out_bibs*' -and -not ($keepSettings -and $r.Dir -eq 'C:\bibs' -and $_.Name -eq 'settings.py') } | Copy-Item -Destination $r.Dir -Recurse -Force
  }
  New-Item -ItemType Directory -Force 'C:\bibs\out_bibs\printed' | Out-Null
  # Ghostscript and pdftops in C:\bibs\tools need the Visual C++ runtime.
  if ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -ErrorAction SilentlyContinue).Installed -ne 1) {
    Start-Process -Wait 'C:\bibs\tools\vcredist_x64.exe' '/install /quiet /norestart'
  }
  # Desktop icon: a shortcut to C:\bibs\nummerlappar.cmd with a bib as icon (a .cmd file cannot have its own icon).
  Remove-Item "$env:PUBLIC\Desktop\nummerlappar.cmd" -ErrorAction SilentlyContinue
  Get-File "$BaseUrl/files/bib.ico" "$Data\bib.ico" | Out-Null
  $sc = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:PUBLIC\Desktop\Nummerlappar.lnk")
  $sc.TargetPath = 'C:\bibs\nummerlappar.cmd'; $sc.WorkingDirectory = 'C:\bibs'; $sc.IconLocation = "$Data\bib.ico,0"; $sc.Save()
}
if ($me.Group -eq 'Nummerlappar') {
  Add-Check { @('printer OKIC542PS with the OKI PS driver', ((Get-Printer OKIC542PS -ErrorAction SilentlyContinue).DriverName -eq 'OKI C542 PS')) }
  Add-Check { & $py -c 'import reportlab, pypdf'; @('Python with reportlab and pypdf', ($LASTEXITCODE -eq 0)) }
  Add-Check { @('Acrobat Reader', (Test-Path $acro)) }
  Add-Check { [xml]$t = (Get-PrintConfiguration OKIC542PS -ErrorAction SilentlyContinue).PrintTicketXML
    $paper = ([regex]::Match($t.OuterXml, 'PageMediaSize"><psf:Option name="([^"]+)"')).Groups[1].Value
    @("OKIC542PS defaults to paper 10mila bib ($paper), landscape", (($paper -like '*UserForm*') -and ($t.OuterXml -match 'psk:Landscape'))) }
  Add-Check { & 'C:\bibs\tools\gs\bin\gswin64c.exe' -q -dNOPAUSE -dBATCH -sDEVICE=nullpage -c quit 2>$null | Out-Null; $gs = $LASTEXITCODE -eq 0
    @('native bib printing in C:\bibs (Ghostscript runs, no Acrobat script), generator in C:\bibs-prod', ($gs -and (Test-Path 'C:\bibs\bib_print.py') -and -not (Test-Path 'C:\bibs\acrobat_print_2.py') -and
      (Test-Path 'C:\bibs-prod\bib_generator_optimized.py') -and (Test-Path "$env:PUBLIC\Desktop\Nummerlappar.lnk") -and ((Get-Content 'C:\bibs\nummerlappar.cmd' -Raw) -match 'bib_print\.py'))) }
}
