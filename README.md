# Phantom Remote for macOS — Unofficial

Eine kleine, **inoffizielle Beta-Fernbedienung** für Devialet-Phantom-Lautsprecher mit DOS 2 und IP-Control-API. Native macOS-App mit Fenster, Menüleiste und globalen Tastenkürzeln.

**Nicht von Devialet entwickelt, geprüft oder unterstützt.** Devialet und Phantom sind Marken ihrer jeweiligen Inhaber. Dieses Projekt enthält keine Herstellerfotos oder Herstellerlogos.

## Transparenz: vollständig „vibe-coded“

Dieses Projekt ist vollständig durch **Vibe Coding mit KI-Assistenten** entstanden. Der Initiator hatte die Idee, beschrieb seine Wünsche und gab Rückmeldungen zur Bedienung und Darstellung. **Er hat keinen Programmcode selbst geschrieben.** Code, Überarbeitungen, Tests und Dokumentation wurden von **Claude Code und OpenAI Codex** erzeugt. Die erste Version entstand mit Claude Code; Codex hat sie anschließend geprüft und für diese öffentliche Beta überarbeitet.

Es gab bislang **kein unabhängiges menschliches Code-Audit**. Automatisierte Tests und erfolgreiche lokale Builds garantieren keine Fehlerfreiheit. Beiträge, unabhängige Reviews und reproduzierbare Fehlerberichte sind willkommen. Das Projekt ist ein experimentelles Community-Werkzeug und erhebt keinen Anspruch auf offiziellen Support oder vollständige Gerätekompatibilität.

## Funktionen

- mDNS/Bonjour-Suche nach `_devialet-http._tcp.local.` einschließlich des angekündigten Ports.
- Alternativ: IPv4-Adresse, IPv6-Adresse oder Hostname mit optionalem Port eingeben.
- Explizite Auswahl eines Systems. Gerät **und** System werden anhand ihrer IDs gespeichert und vor Schreibbefehlen erneut geprüft. Kein automatischer Wechsel auf ein anderes System bei Ausfall.
- Lautstärke, Stummschaltung, unterstützte Wiedergabebefehle und getrennte optische/analoge Eingänge pro Lautsprecher.
- Nachtmodus, Equalizer und Balance, soweit die Firmware die entsprechenden Endpunkte anbietet.
- Identifizierungston pro Lautsprecher und Prüfung seiner HTTP-Erreichbarkeit. Die angezeigten Millisekunden sind HTTP-Antwortzeiten, kein ICMP-Ping.
- Frei veränderbares Fenster: klein nur das Lautstärkerad, normal die volle Steuerung, groß bzw. im Vollbild eine „Now Playing“-Ansicht mit Titel, Quelle und großen Zurück/Play/Weiter-Knöpfen (sofern die Quelle sie anbietet).
- Menüleistensteuerung und globale Kürzel: **⌃⌥↑**, **⌃⌥↓**, **⌃⌥M**.
- Sichtbare Fehlermeldungen. Fehlgeschlagene Befehle werden nicht als erfolgreich bestätigt.
- Update-Prüfung per Knopf (Fußzeile oder App-Menü „Nach Updates suchen …“), optional täglich automatisch. Ab 0.1.4 installiert **„Update installieren“** die neue Version direkt in der App und startet neu – nur auf Knopfdruck, nie still im Hintergrund (Details unter „Selbst-Update“).

## Voraussetzungen und getesteter Umfang

- **macOS 14 oder neuer**. Universal-Build für **Apple Silicon und Intel**.
- Zum Bauen: aktuelle Xcode Command Line Tools mit **Swift 6** oder ein entsprechend eingerichtetes Xcode. Keine externen Swift-/Python-Pakete nötig.
- Mac und Lautsprecher müssen sich gegenseitig im Netzwerk erreichen können. mDNS benötigt Multicast; über getrennte VLANs ist ggf. die manuelle Adresse nötig.
- Phantom mit DOS 2 und aktivem HTTP-IP-Control-Endpunkt, üblicherweise TCP-Port 80. DOS 1 / Spark wird nicht unterstützt.
- Ausgangspunkt der Entwicklung war ein **Phantom-II-95-dB-Stereopaar mit DOS 2.21.2**. Einzelne API-Funktionen wurden dort geprüft. Die Beta wird zusätzlich mit einem simulierten Transport getestet. Andere Geräte, alle Firmwarestände, Intel-Macs und sämtliche macOS-Versionen wurden **nicht** vollständig praktisch getestet.

## Download (Beta, nicht notarisiert)

Unter [Releases](https://github.com/ioni17schick/phantom-remote-macos/releases) gibt es eine fertige Universal-App als `Phantom-Remote-<Version>-unsigned.zip`.

**Wichtig:** Die App ist nur *ad hoc* signiert und **nicht von Apple notarisiert** (keine Developer-ID). macOS blockiert sie deshalb beim ersten Start. Sie wird von GitHub Actions direkt aus dem getaggten Quellcode gebaut, nicht auf einem privaten Rechner; Herkunft und Integrität lassen sich prüfen:

```sh
shasum -a 256 -c Phantom-Remote-*-unsigned.zip.sha256
gh attestation verify Phantom-Remote-*-unsigned.zip --repo ioni17schick/phantom-remote-macos
```

Öffnen (macOS 15 und neuer):

1. Zip entpacken, **Phantom Remote.app** nach *Programme* ziehen und einmal doppelklicken. macOS meldet, dass die App nicht überprüft werden kann → **Fertig**.
2. **Systemeinstellungen → Datenschutz & Sicherheit**, ganz nach unten scrollen → bei „Phantom Remote“ **Trotzdem öffnen** → mit Passwort bestätigen.
3. Ab dann startet die App normal.

Das ist eine bewusste Ausnahme von macOS-Schutzmechanismen. Nur machen, wenn du dem Projekt vertraust; sonst die App wie unten beschrieben selbst bauen – selbst gebaute Apps sind davon nicht betroffen.

## Selbst-Update

„Update installieren“ lädt das Release-Zip dieses Repositorys von GitHub, prüft es und ersetzt die laufende App:

1. Nur Downloads unter `github.com/ioni17schick/phantom-remote-macos/releases/download/…`; Weiterleitungen nur zu `*.githubusercontent.com`, nur HTTPS.
2. SHA-256 muss zur `.sha256`-Datei desselben Releases passen.
3. Das Archiv muss genau eine App mit der Kennung `org.phantomremote.mac`, der erwarteten Version und gültiger Code-Signatur enthalten.
4. Die bisherige Version wird in den **Papierkorb** gelegt (wiederherstellbar); schlägt der Austausch fehl, wird sie automatisch zurückgelegt.

**Bewusster Kompromiss:** Eine von der App selbst geladene Datei trägt keine Quarantäne-Markierung, macOS fragt danach also nicht nach „Trotzdem öffnen“. Die Prüfungen schützen vor fehlerhaften Downloads und fremden Servern, **nicht** vor einem kompromittierten GitHub-Konto dieses Projekts. Wer das nicht möchte, nutzt den Safari-Knopf daneben (Release-Seite) oder baut selbst. Startet die App aus einem schreibgeschützten Ort (z. B. direkt aus „Downloads“), bietet sie nur den Download an.

## Bauen und starten

```sh
./test.sh
./build.sh
open ".build/Phantom Remote.app"
```

`build.sh` baut zunächst nur in `.build/`. Es beendet keine laufende App und verändert keine installierte Version.

Optional installieren, nachdem die bisherige App über **Beenden** geschlossen wurde:

```sh
./build.sh --install
```

Das installiert nach `~/Applications/Phantom Remote.app`. Eine dort vorhandene Version wird als `.bak-beta-<Datum-Uhrzeit>` gesichert. Eine noch laufende Instanz verhindert die Installation.

Lokale Builds sind **ad hoc signiert und nicht notarisiert**. Für öffentliche fertige App-Downloads wäre eine gesonderte Developer-ID-Signierung und Apple-Notarisierung erforderlich, um den üblichen reibungslosen Gatekeeper-Ablauf zu ermöglichen. Die Release-Downloads sind deshalb ausdrücklich als *unsigned* gekennzeichnet; es gibt keine vorgeblich Apple-geprüfte Binärdatei.

## Signierte Release-Builds (für Maintainer)

`scripts/release.sh` baut, signiert mit *Developer ID* und Hardened Runtime, lässt die App von Apple notarisieren und heftet das Ticket an. Ergebnis: `dist/Phantom-Remote-<Version>.zip` plus SHA-256-Datei. Einmalig nötig:

1. Ein Zertifikat **Developer ID Application** im Schlüsselbund (Apple Developer Program, Rolle *Account Holder*).
2. Gespeicherte Notarisierungs-Zugangsdaten, z. B. mit app-spezifischem Passwort:
   `xcrun notarytool store-credentials phantom-notary --apple-id <Apple-ID> --team-id <TEAMID>`

Das Skript bricht ohne Zertifikat oder Profil ab und veröffentlicht nichts selbst.

## Erste Verbindung

1. App öffnen und den Zugriff auf das lokale Netzwerk erlauben, falls macOS danach fragt.
2. **Geräte … → Im Netzwerk suchen (mDNS)** öffnen.
3. Den **System-Leader** des gewünschten Paars auswählen. Die App speichert die bestätigte Geräte-/Systemidentität und Adresse lokal.
4. Alternativ eine IP oder einen Hostnamen eingeben und **Prüfen** wählen. Beispiele für die Schreibweise: `192.0.2.10`, `phantom.local:80` oder `[2001:db8::10]:80` — die IP-Beispiele sind Dokumentationsadressen, keine echten Geräte.
5. Für den Testton des zweiten Lautsprechers muss auch dessen Adresse bekannt sein. mDNS findet beide; ohne mDNS beide Adressen einzeln hinzufügen. Das Hinzufügen des zweiten Lautsprechers ändert das ausgewählte System nicht.

Die Suche wählt bewusst kein beliebiges erstes Gerät aus. Ändert sich bei unveränderter Geräte- und System-ID die Adresse, kann mDNS sie aktualisieren. Nach Neuinstallation, Neugruppierung oder einem Leader-Wechsel ist gegebenenfalls eine erneute bewusste Auswahl erforderlich. Veraltete Suchergebnisse werden beim Auswählen erneut geprüft.

## Lautstärke und Bedienung

- Das Rad nach oben/unten ziehen. Es arbeitet **relativ**, sodass ein Klick auf die Mitte keinen Lautstärkesprung auslöst.
- Schreibbefehle werden geordnet verarbeitet. Schnelle Tastendrücke gehen dadurch nicht durch paralleles Lesen desselben alten Werts verloren.
- **Standardlimit: 60 von 100**, unter **Geräte …** einstellbar. Es begrenzt Befehle dieser App, nicht das Gerät selbst. Andere Apps und Zuspieler können höher stellen. Eine bereits höhere Lautstärke bleibt unverändert; Leiserstellen ist weiterhin möglich.
- Das ist keine garantierte gehörsichere Lautstärke. Vor dem ersten Abspielen mit niedrigem Pegel beginnen.
- Lauterstellen hebt Stummschaltung nicht automatisch auf.
- Ein Klick auf einen Lautsprecher fordert den Identifizierungston an. Die Anzeige bestätigt die erfolgreiche HTTP-Anforderung, nicht eine akustische Messung.
- Fenster schließen lässt die App für Menüleiste und Tastenkürzel weiterlaufen; **Beenden** beendet sie vollständig.

## Audio vom Mac

Diese App ist eine **Fernbedienung, kein Audiotreiber**. Für Ton vom Mac den Lautsprecher separat über AirPlay oder eine passende Kabelverbindung auswählen. Der AirPlay-Knopf öffnet die macOS-Toneinstellungen; er übernimmt nicht selbst die Verbindung. Filmsynchronität hängt vom Zuspieler, Wiedergabeprogramm und Übertragungsweg ab.

## Grenzen dieser Beta

- Die Oberfläche steuert ein ausgewähltes System und zeigt bis zu zwei Lautsprecher. Kein Multiroom-Editor, kein Pairing und keine Firmware-Updates.
- Identifizieren verwendet `/devices/current/identify`, einen in der Entwicklung praktisch bestätigten, hier **als undokumentiert behandelten** Endpunkt. Er kann mit anderer Firmware fehlen; dann erscheint eine Fehlermeldung.
- Standby/Ausschalten ist aus der Beta entfernt, weil Befehl und Aufwachverhalten nicht ausreichend verifiziert waren.
- Balance wird konservativ im Bereich −10 bis +10 angeboten. Der EQ-Bereich und verfügbare Presets werden aus den Geräteantworten übernommen.
- Die Netzwerk-API hat keine Authentifizierung und verwendet HTTP. Identitätsprüfungen schützen vor versehentlicher Fehlzuordnung, **nicht vor aktiver Täuschung im Netzwerk**. Nur in vertrauenswürdigen lokalen Netzen verwenden; keine Portfreigabe ins Internet einrichten.
- Kein automatisches Wiederholen fehlgeschlagener Schreibbefehle. Bei unklarem Ergebnis werden weitere wartende Befehle verworfen und der Zustand neu gelesen.
- mDNS-Probleme: macOS-Netzwerkfreigabe, Firewall, VPN, Gastnetz und Multicast prüfen; alternativ beide Lautsprecher per IP hinzufügen. IPv6-Zonenkennungen werden momentan nicht unterstützt.
- Globale Tastenkürzel können mit anderen Apps kollidieren; die App meldet fehlgeschlagene Registrierung.

## Datenschutz

Keine Telemetrie, kein Cloudkonto und kein Download von Produktgrafiken. Die App kontaktiert die lokal entdeckten oder von dir eingegebenen Geräte. Einzige Ausnahme sind **Update-Prüfung und Selbst-Update**: Sie fragt die öffentliche GitHub-API nach Releases dieses Projekts ab – nur auf Knopfdruck oder, wenn du es unter **Geräte …** einschaltest, höchstens einmal täglich beim Start (standardmäßig aus). Gesendet wird dabei nur `PhantomRemote/<Version>` als User-Agent; GitHub sieht wie bei jedem Abruf deine IP-Adresse. Gespeichert werden das ausgewählte System, Geräte-IDs, Adressen und das Lautstärkelimit in macOS-UserDefaults (`org.phantomremote.mac`). Keine Gerätekennungen oder privaten Netzadressen sind im Quellcode voreingestellt. Seriennummern können in Geräteantworten enthalten sein, werden aber nicht als Adressen zusammengesetzt oder in der Konfiguration gespeichert.

Fehlerberichte und Screenshots bitte vor Veröffentlichung auf private Namen, IDs und Adressen prüfen.

## Tests und Projektaufbau

```sh
./test.sh
python3 scripts/package_source.py --check
python3 scripts/package_source.py
```

Die Regressionstests benutzen ausschließlich einen injizierten Mock-Transport, keine echten Lautsprecher. Sie prüfen unter anderem Adressvalidierung, Gerätezielprüfung, Lautstärkelimit, schnelle Befehlsfolgen, veraltete Polling-Antworten, Fehleranzeigen, mehrere optische Eingänge und individuelle Geräteidentifizierung.

Das Paketwerkzeug erstellt `dist/phantom-remote-source-0.1.0-beta.zip` aus einer expliziten Dateiliste. Alte private Assets, Backups, installierte Apps und Build-Dateien sind nicht enthalten. Die GitHub-Actions-Konfiguration führt Tests, Universal-Build und Veröffentlichungskontrollen aus; sie veröffentlicht keine Releases.

| Datei | Aufgabe |
|---|---|
| `Models.swift` | API-Daten, Adressprüfung, HTTP-Transport, Lautstärkeregeln |
| `Discovery.swift` | Bonjour/mDNS-Erkennung |
| `Updates.swift` | Versionsvergleich und Update-Prüfung über die GitHub-API |
| `Core.swift` | Zustände, feste Gerätezuordnung, geordnete Befehle |
| `Views.swift` | Oberfläche und eigenständige neutrale Lautsprechergrafik |
| `App.swift` | App-Fenster, Menüleiste, Menüs |
| `Tests/RegressionTests.swift` | Isolierte Regressionstests |
| `build.sh`, `test.sh` | Build und Tests ohne Paketabhängigkeiten |

## Lizenz und Beiträge

Der Projektcode und die im Code erstellte neutrale Grafik stehen unter der **MIT-Lizenz**, siehe [LICENSE](LICENSE). Die Lizenz gewährt keine Rechte an Devialet-Marken oder fremden Produktfotos. Eine Kennzeichnung als unabhängig und inoffiziell muss bei der Beschreibung des Projekts klar bleiben.

Bitte [CONTRIBUTING.md](CONTRIBUTING.md) und [SECURITY.md](SECURITY.md) beachten. KI-erzeugte Beiträge sind erlaubt; ihre Herkunft und tatsächliche Tests bitte transparent benennen.
