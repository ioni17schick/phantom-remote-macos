# Beiträge

Dieses Projekt wurde vollständig per Vibe Coding mit Claude Code und OpenAI Codex erstellt. Unabhängige menschliche Reviews sind ausdrücklich willkommen.

- Fehler mit macOS-Version, Gerätemodell, DOS-Version und reproduzierbaren Schritten melden. Namen, Adressen und Gerätekennungen anonymisieren.
- Keine Zugangsdaten, echten Seriennummern, privaten Endpunkte oder Herstellerfotos committen.
- Keine Änderung darf bei App-Start, Discovery oder reinem Lesen Schreibbefehle auslösen.
- Geräteidentität vor jedem Schreibvorgang prüfen. Kein automatischer Wechsel zu einem anderen System.
- Lautstärkeänderungen mit dem Mock-Transport testen; keine unbeaufsichtigten Lautstärke- oder Standby-Tests an realen Geräten.
- Änderungen an der Steuerung brauchen passende Regressionstests. Vor einem PR `./test.sh`, `./build.sh` und `python3 scripts/package_source.py --check` ausführen.
- Herkunft KI-generierter Beiträge und die tatsächlich ausgeführten Tests im PR nennen. Keine menschliche Prüfung behaupten, die nicht stattgefunden hat.
- UI-Texte sind derzeit deutsch. Übersetzungen und Barrierefreiheitsverbesserungen sind willkommen.
