#!/bin/zsh
# Baut, signiert (Developer ID + Hardened Runtime), notarisiert und heftet das Ticket an.
# Ergebnis: dist/Phantom-Remote-<Version>.zip – bereit für ein GitHub-Release.
#
# Voraussetzungen (einmalig, siehe README „Signierte Release-Builds“):
#   - Zertifikat „Developer ID Application: …“ im Schlüsselbund
#   - Notarisierungs-Zugang gespeichert:  xcrun notarytool store-credentials phantom-notary …
#
# Optional: SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"  NOTARY_PROFILE=phantom-notary
set -euo pipefail
cd "${0:A:h}/.."

PROFILE="${NOTARY_PROFILE:-phantom-notary}"
IDENTITY="${SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning | sed -nE 's/.*"(Developer ID Application: [^"]+)".*/\1/p' | head -1)
fi
if [[ -z "$IDENTITY" ]]; then
  print -u2 'Kein „Developer ID Application“-Zertifikat gefunden. Siehe README.'; exit 2
fi
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  print -u2 "Notarisierungsprofil „$PROFILE“ fehlt oder ist ungültig. Siehe README."; exit 2
fi

./test.sh
./build.sh
APP=".build/Phantom Remote.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
OUT="dist/Phantom-Remote-$VERSION.zip"
mkdir -p dist

print "Signiere mit: $IDENTITY"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

SUBMIT=".build/notarize-upload.zip"
rm -f "$SUBMIT"
ditto -c -k --keepParent "$APP" "$SUBMIT"
print "Sende an Apple zur Notarisierung (dauert meist 1–10 Minuten) …"
xcrun notarytool submit "$SUBMIT" --keychain-profile "$PROFILE" --wait --output-format plist > .build/notary-result.plist
STATUS=$(/usr/libexec/PlistBuddy -c 'Print status' .build/notary-result.plist)
ID=$(/usr/libexec/PlistBuddy -c 'Print id' .build/notary-result.plist)
if [[ "$STATUS" != "Accepted" ]]; then
  print -u2 "Notarisierung: $STATUS (ID $ID). Protokoll:"
  xcrun notarytool log "$ID" --keychain-profile "$PROFILE" >&2 || true
  exit 1
fi

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"

rm -f "$OUT"
ditto -c -k --keepParent "$APP" "$OUT"
shasum -a 256 "$OUT" | tee "$OUT.sha256"
print "Fertig: $OUT"
