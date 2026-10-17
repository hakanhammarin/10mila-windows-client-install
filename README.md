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
| sportident | SPORTident USB driver | x | |
| power | never sleep, dim or lock; lid and buttons do nothing; no screen saver | x | x |
| powerloss | PowerLoss agent at boot | x | |
| ola | OLA from SOFT's MSI, properties in `C:\ProgramData\OLA6`, OLA-Klient and TA-Klient icons | x | |
| nummerlappar | bib printing station on PRINT-xx (OKI C542 PS, Python, Acrobat Reader, `C:\bibs`) | x | |
| receipt | Star TSP143 driver; "Hello world" on 72 mm paper at boot and when plugged in | x | x |
| firewall | desktop icon "Brandvägg event": on = only local network in and out, no internet | x | x |
| wallpaper | BGInfo replacement: Dator, Funktion, Uppgift upper right (oringen: the O-Ringen banner, `C:\bgi\Funktion.txt` and `Uppgift.txt`; BGInfo off) | x | x |
| desktop | desktop icons in rows along the top, launch icons first | x | x |

Run single modules with `-Modules firewall,receipt`. Options: `-Name TA-03`, `-Uppgift "..."`, `-OlaServer 192.168.1.21`, `-OlaEvent "..."`, `-OlaVersion 6.6.2`, `-Reboot`, `-BaseUrl` / `-ReleaseUrl` (test from another host).

## Files

- `install.ps1` loads `modules/<name>.ps1`; `files/` holds the scripts installed on the laptop (wallpaper, desktop row, receipt watcher, firewall switch); `restore.ps1` undoes it.
- `computers.csv` - functions and computer names. `config/` - OLA defaults (no passwords).
- Release: SOFT_OLA-<version>.msi, powerloss-agent.exe (`build-dist.sh`), oki-c542-ps.zip, star-tsp100.zip (vendor drivers as they come).
- `todo.md` - what is done and open. `collected/` (gitignored) - settings copied from laptops; may hold passwords.

Nothing secret goes in this repo: it is downloaded from a public URL.
