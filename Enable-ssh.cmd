@echo off
rem New laptop: ssh server on port 22 for remote setup. Asks for administrator.
curl -fsSLo "%TEMP%\enable-ssh.ps1" https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/enable-ssh.ps1 || (echo Kunde inte ladda ner enable-ssh.ps1 & pause & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\enable-ssh.ps1"  %*
