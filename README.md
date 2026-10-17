# 10MILA Windows client install

Sets up crew laptops for 10MILA, and parts of it for the O-Ringen laptops, from one public command. Everything it changes is saved first, so `restore.ps1` puts a laptop back (the O-Ringen laptops after 10MILA).

## Run

Open **cmd as administrator** (not PowerShell: there `curl` and `&&` mean something else) and paste:

```
curl -fsSLo %TEMP%\10mila.ps1 https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/install.ps1 && powershell -ExecutionPolicy Bypass -File %TEMP%\10mila.ps1
```

10MILA laptop: pick the function and the number on the laptop's label. O-Ringen laptop: add `-Profile oringen`. The script ends in PASS or FAILED (log: `C:\ProgramData\10mila\install.log`). Running it again is safe.

Back to how it was (O-Ringen layout, BGInfo, firewall, power, name):

```
curl -fsSLo %TEMP%\restore.ps1 https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/restore.ps1 && powershell -ExecutionPolicy Bypass -File %TEMP%\restore.ps1
```

## Profiles and modules

| Module | What it does | 10mila | oringen |
|---|---|---|---|
| backup | saves registry, power, firewall, hosts, OLA6, startup and desktops once, for restore.ps1 | always | always |
| name | computer name picker by function (`computers.csv`) | x | |
| region | time zone Stockholm, Swedish date/time format, region Sweden; clock synced | x | x |
| sportident | SPORTident USB driver | x | |
| power | never sleep, dim or lock; lid and buttons do nothing; no screen saver | x | x |
| autologon | automatic sign-in with the account signed in now; password asked for (or `TENMILA_AUTOLOGON_PASSWORD`), kept as an LSA secret | x | x |
| powerloss | PowerLoss agent at boot | x | |
| ola | OLA from SOFT's MSI, properties in `C:\ProgramData\OLA6`, OLA-Klient and TA-Klient icons | x | |
| nummerlappar | bib printing station on PRINT-xx: OKI C542 PS with default paper "10mila bib" (225x160 landscape, fed short edge first), Python, Acrobat Reader, `C:\bibs` printing in descending order | x | |
| receipt | Star TSP143 driver; "Hello world" on 72 mm paper at boot and when plugged in | x | x |
| firewall | SIRAP TCP 10001 always open; "Brandvägg event" in TOOLS: on = every Windows allow rule off, in only ssh/PowerLoss/mDNS/DHCP, out only private ranges; no internet | x | x |
| update | "10MILA UPDATE" in TOOLS and at every boot: the one-liner again with this laptop's choices (`C:\ProgramData\10mila\profile.json`) and the versions in git | x | x |
| wallpaper | BGInfo replacement: Dator, Funktion, Uppgift, the OKI printer IP from hosts and the event firewall state upper right; 10mila: the 10MILA logo lower right (oringen: the O-Ringen banner, `C:\bgi\Funktion.txt` and `Uppgift.txt`; BGInfo off) | x | x |
| desktop | clean desktop: launch icons and a TOOLS folder, no Recycle Bin, scripts moved to TOOLS, O-Ringen program folders hidden; rows along the top | x | x |
| taskbar | taskbar holds only the launch programs; no Search, Task view, Widgets, Chat; tray icons untouched (applies at the next sign-in) | x | x |

Run single modules with `-Modules firewall,receipt`.

**Freeze windows:** `freeze.csv` lists date-time windows (race weekend, rehearsal) when install and update refuse to run (exit 3, nothing changed). Test with `-SimulateNow "2027-05-01 10:00"`. The event firewall blocks GitHub anyway while it is on. Options: `-Name TA-03`, `-Uppgift "..."`, `-OlaServer 192.168.1.21`, `-OlaEvent "..."`, `-OlaVersion 6.6.2`, `-Reboot`, `-BaseUrl` / `-ReleaseUrl` (test from another host).

## Files

- `install.ps1` loads `modules/<name>.ps1`; `files/` holds the scripts installed on the laptop (wallpaper, desktop row, receipt watcher, firewall switch); `restore.ps1` undoes it.
- `computers.csv` - functions and computer names. `config/` - OLA defaults (no passwords).
- Release: SOFT_OLA-<version>.msi, powerloss-agent.exe (`build-dist.sh`), oki-c542-ps.zip, star-tsp100.zip (vendor drivers as they come).
- `todo.md` - what is done and open. `collected/` (gitignored) - settings copied from laptops; may hold passwords.

Nothing secret goes in this repo: it is downloaded from a public URL.
