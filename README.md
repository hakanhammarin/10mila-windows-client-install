# 10MILA Windows client install

Sets up one crew laptop for 10MILA: computer name by function, SportIdent USB driver, PowerLoss agent, OLA client with defaults, and a light grey wallpaper with the function and name in the upper right corner.

## Run

Open **cmd as administrator** (not PowerShell: there `curl` and `&&` mean something else) and paste:

```
curl -fsSLo %TEMP%\10mila.ps1 https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/install.ps1 && powershell -ExecutionPolicy Bypass -File %TEMP%\10mila.ps1
```

Pick the function and the number on the laptop's label. The script ends in PASS or FAILED (log: `C:\ProgramData\10mila\install.log`). Restart the laptop to use the new name. Running it again is safe.

Options: `-Name TA-03` (no questions), `-OlaServer 192.168.1.21`, `-OlaEvent tiomila2026`, `-Reboot`, `-BaseUrl` / `-ReleaseUrl` (test from another host).

## Files

- `install.ps1` - the installer. `computers.csv` - functions and computer names. `config/` - OLA defaults (no passwords).
- `build-dist.sh` - builds `dist/powerloss-agent.exe` and `dist/OLA-Klient.zip` for the GitHub release.
- `todo.md` - what is done and open.

Nothing secret goes in this repo: it is downloaded from a public URL.
