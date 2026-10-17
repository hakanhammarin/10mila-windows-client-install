# Windows crew laptops - todo

One elevated cmd line per laptop (README.md), about 40 laptops, run by crew members from home.

## Done (tested on 10.0.0.37, HP EliteBook 840 G6, Windows 11 IoT Enterprise LTSC 24H2, 2026-10-16)

- [x] Computer name picker by function (`computers.csv`: group, function, name prefix, count). PASS as IT-01 and TA-03; name applied after reboot.
- [x] SportIdent USB driver: SPORTident's own signed package 2026-06-09 (`pnputil /add-driver sportident.inf`). The Silicon Labs CP210x zip is not used: silabs.com answers 403 to scripted downloads.
- [x] PowerLoss agent: exe from `build-dist.sh`, settings.json with computer_name and location = function, boot task as SYSTEM with restart, firewall rule. Answers on :3000 after reboot, also from the LAN.
- [x] OLA 6.5.0 from SOFT_OLA-6.5.0.msi, `msiexec /qn` (skipped when that version is installed), C:\Program Files\OLA 6. Settings live in C:\ProgramData\OLA6: ola.properties and SOFT.properties written there (OLA server 192.168.1.21:8081, event "Tiomila, Tranås (Stafettligan, #3)" as the 2026 server shows it). Desktop icon from the MSI's start menu shortcut; starts 6.5.0 (tested). Replaces the 6.4.10 zip.
- [x] Wallpaper: light grey (190,190,190), function and name upper right, machine-wide via PersonalizationCSP.
- [x] Power: machine policy (HKLM\SOFTWARE\Policies\Microsoft\Power\PowerSettings) 0 on AC and battery for display off, dim, sleep, hibernate, unattended sleep, disk, lid, power and sleep button, password on wake; hibernate off, USB selective suspend and PCIe power saving off, network adapters never sleep, no idle lock, screen saver off by policy in every profile. Replaces an older local policy on 10.0.0.37 that turned the screen off after 30 min on battery.
- [x] Nummerlappar (PRINT-xx): hosts `192.168.1.27 OKIC542PS`, port okic542, paper form "10mila" 160 x 225 mm, Python 3.12 with reportlab and pypdf, Acrobat Reader 64-bit (sv_SE, no EULA flag: accepted at the first test print), C:\bibs from 10mila_bib_print_via_acrobat_reader_on_windows (PDFs in out_bibs kept), C:\bibs-prod from 10mila_bibs_prod, nummerlappar.cmd on the desktop. Tested as PRINT-01: all ok except the OKI driver.

## Open

- [x] Public: repo public (Håkan, 2026-10-16), release v2026.10.16 with OLA-Klient.zip, powerloss-agent.exe, oki-c542-ps.zip. The real one-liner from raw.githubusercontent.com: PASS as PRINT-01 on 10.0.0.37.
- [x] OKI C542 PS driver: OKI's OKW3S05H106_303250.exe (v1.0.6, from oki.com, downloaded by Håkan, sha256 3ee433b5...d8582) self-extracts its `Driver` folder when started on Windows; zipped as `dist/oki-c542-ps.zip` (302 files, OKW3S05H.INF, model "OKI C542 PS"). PASS as PRINT-01 2026-10-16.
- [ ] Other printers (ola.properties prints bib numbers to "Phaser 6510 WiFi"; 10mila_bibs_prod settings name "Xerox 6510 PS"): which ones, and on which functions?
- [ ] Driver settings that live in the OKI driver (tray, "10mila" as default paper, landscape) per the printer PDF: set by hand at the first test print for now.
- [ ] Computer names and counts per function in `computers.csv` are a first guess (40 in total). Check against the real laptop list and labels.
- [ ] OLA event name on the race server (`-OlaEvent`) and server IP (`-OlaServer`, default 192.168.1.21) for 2027.
- [ ] Start the OLA client once by hand on a test laptop: check that it opens the server dialog with the defaults (not tested over ssh, it is a GUI).
- [ ] Look at the wallpaper on the screen after logon (only the file and the policy were checked over ssh).
- [ ] PowerLoss as a real Windows service needs a service handler in the agent (monitoring owns powerloss-agent); the boot task works meanwhile.

## Upgrade to OLA 6.6.2 (done 2026-10-17)

- [x] SOFT_OLA-6.6.2.msi (sha256 f92b0f36...998e0d6) in release v2026.10.16 next to 6.5.0 (kept for rollback); `$OlaVersion` default 6.6.2.
- [x] SOFT changed the UpgradeCode (6.5.0 {6B1C5800-...}, 6.6.2 {C1216E3E-...}): the MSI installs beside 6.5, not over it. install.ps1 now removes every other "OLA 6" version (`msiexec /x` product code) and then installs the wanted one with REINSTALL=ALL REINSTALLMODE=amus, because the removal takes shared files and the start menu shortcut with it. The check caught the side by side install (two entries).
- [x] Tested on 10.0.0.37: 6.6.2 -> 6.5.0 (rollback) PASS, 6.5.0 -> 6.6.2 PASS, rerun 6.6.2 PASS (MSI skipped); the desktop icon starts 6.6.2.
- [ ] Servers to 6.6.2 and the SQL migration: the `upgrade` agent (ola-upgrade.sh), not this repo.

## Modules, O-Ringen profile and restore (2026-10-17)

O-Ringen readout laptop TA31 (10.0.0.40, Windows 10 Enterprise, user funktionar): BGInfo from C:\bgi (Oringen.bgi: "Dator: <Host Name>", Funktion and Uppgift from C:\bgi\Funktion.txt / Uppgift.txt, banner o_ringen_cover.jpg), old OLA client in Desktop\OLA-klient and TA-klient (settings in C:\ProgramData\OLA6), Star TSP100 Cutter (TSP143) on USB, driver smjt100.inf. Copies in collected/oringen-ta31 (gitignored).

- [x] install.ps1 split into modules/ with profiles 10mila and oringen; backup module (first run only) and restore.ps1.
- [x] BGInfo off on TA31 (startup BGI.cmd kept in the restore folder); wallpaper module draws Dator, Funktion, Uppgift upper right at every logon (per user, DPI aware, fill).
- [x] Desktop icons in rows along the top at logon (IFolderView, launch icons first); TA-Klient icon added for the MSI install.
- [x] Receipt: Star driver from the release; watcher task prints "Hello world" on 72 mm receipt paper at boot and on plug-in. Printed on TA31.
- [x] Event firewall switch (desktop icon, asks for UAC): on = inbound ssh, PowerLoss, mDNS, core networking; outbound only RFC 1918/link-local/multicast; internet blocked by a block rule. Tested on 10.0.0.37: internet blocked, LAN, ssh and PowerLoss ok; off restores profiles and the 95 rules it disabled. Switching over ssh drops that ssh session (start it detached if done remotely).
- [x] Restore tested on TA31: tasks, rules, policies, wallpaper, icon layout and BGInfo back. Lesson: never delete-and-reimport a shared key (Policies\System holds UAC); only keys we own.
- [ ] O-Ringen bib printing with the OLA MSI: bib PDFs are relative to the start folder (Desktop\OLA-klient via OLA.bat). Validate on a print laptop before O-Ringen uses the MSI.
- [ ] Check the desktop icon "Brandvägg event" with a person at the screen (UAC prompt, message box).

## Update, freeze windows, clean desktop and taskbar (2026-10-17)

- [x] freeze.csv: 2027-04-30 14:00 to 2027-05-02 23:59. Simulated: 2027-05-01 10:00 = FROZEN exit 3, 2027-05-03 08:00 runs.
- [x] "10MILA UPDATE" in TOOLS (asks for UAC) and the boot task "10mila update" (SYSTEM, 2 min after start): rerun with profile.json; no internet = nothing changed (update.log).
- [x] Firewall on: all Windows allow rules off (out: every one; in: all but core networking), one allow-out rule for private ranges. Tested on TA31: DHCP renew ok (lease renewed, same address), mDNS name answered to the Mac, LAN ok, internet and DNS to 8.8.8.8 blocked; off brought back 102 outbound rules.
- [x] Clean desktop and TOOLS; Recycle Bin hidden; taskbar pins through a layout policy (seen after the next sign-in); extra buttons off by policy where Windows allows it.
- [x] Hello world: 20 mm feed before the cut.
- [ ] Rehearsal on the arena: the freeze from 1 h before it needs its date and time in freeze.csv.
- [ ] Check the taskbar pins after a sign-in on .37 (Windows 11) and TA31 (Windows 10).

## Bib paper, autologin, logo (2026-10-17)

- [x] OKIC542PS default: paper "10mila bib" (form 160 x 225 mm = fed short edge first), landscape, set through System.Printing; checked as ns0000:UserForm197 + psk:Landscape on .37.
- [x] Descending bib order: install patches the loop in C:\bibs\acrobat_print_2.py (my token gets 403 on 10mila_bib_print_via_acrobat_reader_on_windows). Drop the patch when that repo has it.
- [x] Wallpaper: "Skrivare OKI: <ip>" from hosts; 10MILA logo (Tranås 2026) lower right on the 10mila style. Desktop icons Large.
- [x] Automatic sign-in (LSA secret DefaultPassword, Winlogon values saved for restore; restore clears the secret). PASS on .37.
- [ ] Give the token write access to 10mila_bib_print_via_acrobat_reader_on_windows, or merge the descending loop there.
- [x] Wallpaper shows "Brandvägg event: PÅ/AV"; the switch redraws it. SIRAP TCP 10001 inbound rule in group 10mila (kept when the event firewall is on). Region module: W. Europe Standard Time, sv-SE, GeoId 221 (system locale after restart).
- [x] Taskbar pins: .bat programs are pinned through cmd.exe (the taskbar refuses .bat targets, so the first layout showed no pins).

## Battery test (2026-10-17)

- [x] battery-log.ps1 (task "10mila battery", SYSTEM): polls every 10 s, a CSV row a minute on battery; run closed when AC is back or at the next start after the battery ran out; last.json shown on the wallpaper with SOH (design capacity from the battery report when WMI has none). Close after "ran out" tested with a simulated run on .37.
- .37: design 50 012 mWh, full 35 020 mWh = SOH 70 %, 116 cycles.
- .40 (Revolve 810 G1): the gauge says 100 % and full = design 37 740 mWh (SOH 100 %), cycle count 0, never a minute on battery in its history since 2022, and 8.1 V on AC where a 3-cell pack reads about 12 V. Two unexpected power losses (Kernel-Power 41) at 16:24 and 16:28 when unplugged. The gauge is not to be trusted: only a real run shows it.
- [x] LibreOffice 26.8.1 for O-Ringen deltagarservice (module libreoffice in the oringen profile, silent MSI, Swedish UI, no update checks). Installed on .40.
- [x] Battery verdict (verdict.json): DEAD after a test that ran out within 5 min, or 2+ sudden power losses (Kernel-Power 41, no bugcheck, no power button) since the last good test. .40 = DEAD (16:24, 16:28), red line on the wallpaper; .37 = OK.
- [x] Reader module on every laptop: Acrobat Reader, default for .pdf through the DefaultAssociationsConfiguration policy (applies at sign-in), FeatureLockDown policies for upsell, AI assistant, cloud, welcome screen, messages, updater; AdobeARMservice disabled. Installed on .37 and .40.
- [ ] Reader EULA still shows at the first start on each laptop (not accepted on anyone's behalf).

## Deltagarservice laptop .46, Config+, Teams, profile tool (2026-10-17)

- [x] siconfig (Config+ 2.12.0 MSI, icon in TOOLS), teams (all Teams variants removed), "Rensa profil" in TOOLS: tested on .40.
- [x] JSON state files are written beside and moved over: .40's values.json was all zero bytes after its sudden power losses, so single registry values changed by the 10mila template on .40 cannot be put back by restore.ps1 there (snapshot, reg exports and moves are intact).
- [ ] .46 (user funktionär): not reachable yet (no ping, no ssh). Then: O-Ringen profile with -KeepOnDesktop deltagarservice.
- [x] Battery estimate: every 10 min on battery (>= 10 min and 3 % drop) estimate.json with time left and time from full, on the wallpaper; the closed run keeps FullMinutes ("räcker ca 3 h 20 min från full", simulated on .37).
- [x] SportIdent signed driver in the O-Ringen profile too; old 2014 packages (sivcp.inf/silabenm.inf, older SPORTident) removed. Rensa profil also removes Microsoft accounts (IdentityCRL, TokenBroker) and the Edge/Chrome profile: cleared gary.jonforsen@outlook.com on .46.
- [x] AutoPlay/AutoRun off in both profiles (NoDriveTypeAutoRun 255, NoAutorun, NoAutoplayfornonVolume, per-user DisableAutoplay; values saved for restore). PASS on .46.
- [x] Edge module (both profiles): HideFirstRunExperience and the other no-question policies, local start page C:\ProgramData\10mila\start\index.html (event graphics, buttons Google, Eventor + 10MILA/online or Gmail/O-Ringen/Resultat) as home, new tab and startup; Edge desktop icon kept away. PASS on .46; Edge on screen not seen yet (tasks in the user session stayed queued during the test).
