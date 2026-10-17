@echo off
rem Back to how the laptop was before the 10MILA install. Asks for administrator.
curl -fsSLo "%TEMP%\restore.ps1" https://raw.githubusercontent.com/hakanhammarin/10mila-windows-client-install/main/restore.ps1 || (echo Kunde inte ladda ner restore.ps1 & pause & exit /b 1)
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\restore.ps1"  %*
