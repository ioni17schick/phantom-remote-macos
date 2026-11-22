# Sicherheit und Fehlerberichte

Experimentelle Beta, kein professionell auditiertes Produkt. Es gibt keine Zusage von Reaktionszeiten oder Langzeitsupport.

Die Devialet-IP-Control-API läuft lokal über unverschlüsseltes HTTP ohne Authentifizierung. Die App lehnt HTTP-Weiterleitungen ab und prüft Geräte- und System-ID vor Schreiboperationen. Diese Prüfungen sind keine kryptografische Authentifizierung. Nur in vertrauenswürdigen Netzen betreiben; keine API-Ports ins Internet freigeben.

Das Selbst-Update (ab 0.1.4) lädt nur Release-Assets dieses Repositorys, prüft SHA-256, Bundle-ID, Version und Code-Signatur und läuft nur auf Knopfdruck. Es umgeht die Gatekeeper-Nachfrage (keine Quarantäne-Markierung) und vertraut damit dem GitHub-Konto des Projekts; die Herkunft eines Downloads lässt sich zusätzlich mit `gh attestation verify` prüfen.

Die App erzeugt keine Telemetrie und enthält keine Zugangsdaten. Geräteadressen und IDs werden lokal in UserDefaults gespeichert. Vor Fehlerberichten private Details entfernen.

Sicherheitsprobleme mit reproduzierbaren, anonymisierten Beispielen melden. Falls das spätere GitHub-Repository private Vulnerability Reports anbietet, diese verwenden. Keine personenbezogenen Daten oder Zugangsdaten in öffentliche Issues stellen.
