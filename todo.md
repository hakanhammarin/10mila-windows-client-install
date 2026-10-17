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
