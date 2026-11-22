Inoffizielle Beta-Fernbedienung für Devialet Phantom (DOS 2) – **nicht von Devialet**.

> ⚠️ **Nicht notarisiert.** Diese App ist nur ad hoc signiert, nicht mit einer Apple-Developer-ID. macOS blockiert sie beim ersten Start. Anleitung zum Öffnen und zur Prüfung: siehe [README → Download](https://github.com/ioni17schick/phantom-remote-macos#download-beta-nicht-notarisiert). Wer dem nicht vertrauen möchte, baut die App mit `./build.sh` selbst aus dem Quellcode.

- Universal-App (Apple Silicon und Intel), macOS 14 oder neuer
- Von GitHub Actions aus genau diesem Tag gebaut, mit Herkunftsnachweis:
  `gh attestation verify Phantom-Remote-*-unsigned.zip --repo ioni17schick/phantom-remote-macos`
- SHA-256-Prüfsumme liegt als `.sha256`-Datei bei

Das Projekt ist vollständig per Vibe Coding mit KI-Assistenten entstanden; es gab kein unabhängiges menschliches Code-Audit. Änderungen: siehe [CHANGELOG](https://github.com/ioni17schick/phantom-remote-macos/blob/main/CHANGELOG.md).
