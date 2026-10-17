@echo off
rem O-Ringen laptop: double-click. Asks for administrator.
curl -fsSLo "%TEMP%\install.ps1" https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/install.ps1 || (echo Kunde inte ladda ner install.ps1 & pause & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\install.ps1" -Profile oringen %*
