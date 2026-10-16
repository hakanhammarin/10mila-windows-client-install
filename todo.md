# Windows crew laptops - todo

One elevated cmd line per laptop (README.md), about 40 laptops, run by crew members from home.

## Done (tested on 10.0.0.37, HP EliteBook 840 G6, Windows 11 IoT Enterprise LTSC 24H2, 2026-10-16)

- [x] Computer name picker by function (`computers.csv`: group, function, name prefix, count). PASS as IT-01 and TA-03; name applied after reboot.
- [x] SportIdent USB driver: SPORTident's own signed package 2026-06-09 (`pnputil /add-driver sportident.inf`). The Silicon Labs CP210x zip is not used: silabs.com answers 403 to scripted downloads.
- [x] PowerLoss agent: exe from `build-dist.sh`, settings.json with computer_name and location = function, boot task as SYSTEM with restart, firewall rule. Answers on :3000 after reboot, also from the LAN.
- [x] OLA client 6.4.10 in C:\OLA-Klient with ola.properties and SOFT.properties defaults (OLA server 192.168.1.21:8081, event tiomila2026), shortcut on the public desktop.
- [x] Wallpaper: light grey (190,190,190), function and name upper right, machine-wide via PersonalizationCSP.

## Open

- [ ] Public path. The repo is private: raw GitHub URLs need it public, and the release must carry `powerloss-agent.exe` and `OLA-Klient.zip` (built by `build-dist.sh`, 10 MB and 90 MB). Håkan decides: make the repo public, and whether the OLA client may be published (otherwise host the zip elsewhere and pass `-ReleaseUrl`).
- [ ] Printer drivers: which printers (model, IP or queue name)? ola.properties prints bib numbers to "Phaser 6510 WiFi".
- [ ] Computer names and counts per function in `computers.csv` are a first guess (40 in total). Check against the real laptop list and labels.
- [ ] OLA event name on the race server (`-OlaEvent`, default tiomila2026) and server IP (`-OlaServer`, default 192.168.1.21) for 2027.
- [ ] Start the OLA client once by hand on a test laptop: check that it opens the server dialog with the defaults (not tested over ssh, it is a GUI).
- [ ] Look at the wallpaper on the screen after logon (only the file and the policy were checked over ssh).
- [ ] PowerLoss as a real Windows service needs a service handler in the agent (monitoring owns powerloss-agent); the boot task works meanwhile.
