# Changelog

## 0.1.2-beta — 2026-11-22

- Update-Prüfung: Knopf in der Fußzeile und App-Menü „Nach Updates suchen …“; optional einmal täglich automatisch (standardmäßig aus).
- Bei einer neuen Version wird nur die Release-Seite geöffnet – keine automatische Installation, da die App nicht notarisiert ist.
- Nur Release-Links genau dieses Repositorys werden geöffnet; Entwürfe werden ignoriert.
- Datenschutz-Abschnitt im README entsprechend ergänzt.
- 84 Regressionstests (Versionsvergleich, Link-Prüfung, Standard „aus“, Tagesabstand).

## 0.1.1-beta — 2026-11-22

Korrekturen nach einem externen KI-Code-Review (Grok); jede Korrektur hat einen Regressionstest, der ohne sie fehlschlägt.

- Lautstärke, Stummschaltung, Wiedergabe, Quelle, Nachtmodus und EQ: `await` kehrt erst zurück, wenn der Befehl wirklich abgeschlossen ist (vorher nur „eingereiht“).
- „Von Quelle/Firmware nicht unterstützt“ wird von Verbindungsfehlern getrennt: Meldung ja, aber kein Offline-Zustand und keine verworfenen Folgebefehle.
- Verbindungsverlust beim Abfragen erscheint jetzt auch als Fehlerhinweis, nicht nur im Statustext.
- Fensterhöhe folgt dem Inhalt, höchstens bis zur Bildschirmhöhe; darüber wird gescrollt.
- Lautstärke-Einblendung auf Statusleisten-Ebene statt Bildschirmschoner-Ebene.
- Globale Tastenkürzel werden beim Beenden abgemeldet; bei Belegung nennt die Meldung die betroffenen Kürzel.
- Leere Quellen-IDs vom Gerät werden nicht mehr als Befehl gesendet.
- 67 Regressionstests.

## 0.1.0-beta — 2026-11-22

Erste zur öffentlichen Prüfung vorbereitete Version; noch kein veröffentlichtes Release.

- Explizite Geräteauswahl über mDNS/Bonjour oder manuell geprüfte Adresse.
- Persistente Geräte-/System-ID; kein Wechsel auf fremde Systeme nach Ausfall.
- Individuelle Geräteadressen werden ermittelt, nicht aus Seriennummern erraten.
- Relative Lautstärkegeste, Standardlimit 60, sequenzielle Befehlsverarbeitung.
- Sichtbare Fehler, Zustandsabgleich, Schutz vor veralteten Polling-Antworten.
- Beide optischen Eingänge separat wählbar; unterstützte Funktionen dynamisch anzeigen.
- Unverifizierte Standby-Funktion entfernt.
- Eigene neutrale Grafik; keine Herstellerbilder im öffentlichen Build.
- Swift-6-Concurrency-Prüfung, Mock-Regressionstests und macOS-CI.
- Universal-Build für arm64/x86_64; Installation nur explizit und mit Backup.
- MIT-Lizenz und transparente Dokumentation der vollständigen KI-Implementierung.
- Einheitlicher Name „Phantom Remote“ (App-Bundle, Fenster, Installation).
- Keine Schreibbefehle für unveränderten Nachtmodus oder unveränderte EQ-Voreinstellung.
- Lautstärkelimit wird intern auf 0–100 begrenzt, nicht nur beim Speichern.
- Fensterhöhe folgt dem Inhalt; Fußzeile und Fehlerbanner werden nicht abgeschnitten.
- Unsignierter Universal-Download, gebaut von GitHub Actions mit Herkunftsnachweis (Build Provenance) und SHA-256.
- 60 Regressionstests, u. a. für Werte-Begrenzung, untergeschobene Quellen-IDs, fremde System-IDs und vergessene Systeme.
