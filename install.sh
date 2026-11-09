#!/bin/zsh
# Baut die App, kopiert sie nach /Applications und startet sie.
# Aufruf: ./install.sh
set -e
cd "${0:A:h}"
ZIEL="/Applications/Formelschreiber.app"

echo "Baue Release-Version …"
xcodebuild -project Formelschreiber.xcodeproj -scheme Formelschreiber -configuration Release -derivedDataPath build build -quiet 2>/dev/null
QUELLE="build/Build/Products/Release/Formelschreiber.app"
[[ -x "$QUELLE/Contents/MacOS/Formelschreiber" ]] || { echo "Build fehlgeschlagen."; exit 1; }

pkill -x Formelschreiber 2>/dev/null || true
rm -rf "$ZIEL"
ditto "$QUELLE" "$ZIEL"
# Mit dem Entwicklerzertifikat signieren: Dann bleibt die Freigabe „Bedienungshilfen“
# auch nach dem nächsten Update bestehen. Ohne Zertifikat bleibt die Ad-hoc-Signatur.
IDENTITAET=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
if [[ -n "$IDENTITAET" ]]; then
  codesign --force --sign "$IDENTITAET" "$ZIEL" 2>/dev/null && echo "Signiert mit: $IDENTITAET" || echo "Signieren übersprungen (Ad-hoc)."
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$ZIEL"
open "$ZIEL"
echo "Installiert und gestartet: $ZIEL"
