# Security and bug reports

Experimental beta, not a professionally audited product. No guaranteed response times or long-term support.

The Devialet IP Control API runs over unencrypted HTTP without authentication on the local network. The app rejects HTTP redirects to the speakers and checks device and system ID before every write. These checks are not cryptographic authentication. Run it only on trusted networks; never expose the API port to the internet.

The self-update only downloads release assets of this repository, verifies SHA-256, bundle ID, version and code signature, and runs only when the user clicks. It skips the Gatekeeper prompt (no quarantine flag) and therefore trusts the project’s GitHub account; a download’s origin can additionally be checked with `gh attestation verify`.

The app sends no telemetry and contains no credentials. Device addresses and IDs are stored locally in UserDefaults. Remove private details before filing reports.

Report security issues with reproducible, anonymized examples. Use GitHub’s private vulnerability reporting if available. Never put personal data or credentials into public issues.
