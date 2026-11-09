#!/usr/bin/env bash
# Build dist/glyph-lite-<version>.zip (runs validate.sh first).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
./validate.sh
v="$(cat VERSION)"; mkdir -p dist
rm -f "dist/glyph-lite-$v.zip"
parent="$(basename "$PWD")"
(cd .. && zip -qr "$parent/dist/glyph-lite-$v.zip" "$parent" -x "$parent/dist/*" -x "$parent/.git/*" -x '*/__pycache__/*')
( cd dist && sha256sum "glyph-lite-$v.zip" > "glyph-lite-$v.zip.sha256" )
echo "dist/glyph-lite-$v.zip"
