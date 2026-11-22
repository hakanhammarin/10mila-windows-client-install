#!/usr/bin/env bash
# build-dist.sh - build dist/powerloss-agent.exe from ../powerloss-agent for the GitHub release.
# The other release files are vendor packages uploaded as they are: SOFT_OLA-<version>.msi (from SOFT) and
# oki-c542-ps.zip (the Driver folder that OKI's OKW3S05H106_303250.exe unpacks when started on Windows).
# StarterClock.appxbundle and its dependency packages (Tak-Soft's Store app 9WZDNCRFJ937) are kept in dist/ too, but NOT in
# the release: ../10mila_automation/search.sh serves them on the LAN (install.ps1 -StarterClockUrl).
set -euo pipefail
cd "$(dirname "$0")"; mkdir -p dist
(cd ../powerloss-agent && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o "$OLDPWD/dist/powerloss-agent.exe" .)
ls -lh dist && echo PASS
