#!/usr/bin/env bash
# build-dist.sh - build the release files the installer downloads: dist/powerloss-agent.exe and dist/OLA-Klient.zip.
# Run on the Mac next to ../powerloss-agent and ../OLA-Klient. dist/ is gitignored; upload its files to a GitHub release.
set -euo pipefail
cd "$(dirname "$0")"; rm -rf dist; mkdir -p dist
(cd ../powerloss-agent && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o "$OLDPWD/dist/powerloss-agent.exe" .)
# OLA client without its OLA6 folders (local databases, logs and the Mac's ola.properties with a password); install.ps1 writes OLA6.
(cd .. && zip -qr "$OLDPWD/dist/OLA-Klient.zip" OLA-Klient -x 'OLA-Klient/OLA6/*' 'OLA-Klient/bin/OLA6/*' '*.DS_Store' 'OLA-Klient/*.sh' 'OLA-Klient/bin/OLA-Klient')
if unzip -l dist/OLA-Klient.zip | grep -Ei 'ola\.properties|soft\.properties'; then echo "FAILED: OLA properties in the zip"; exit 1; fi
ls -lh dist && echo PASS
