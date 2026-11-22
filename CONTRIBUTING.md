# Contributing

This project was created entirely by vibe coding with Claude Code and OpenAI Codex. Independent human reviews are explicitly welcome.

- Report bugs with macOS version, speaker model, DOS version and reproducible steps. Anonymize names, addresses and device IDs.
- Never commit credentials, real serial numbers, private endpoints or manufacturer photos.
- No change may send write commands on app start, during discovery or while only reading.
- Verify the device identity before every write. Never switch to another system automatically.
- Test volume changes with the mock transport; no unattended volume or standby tests on real devices.
- Changes to the control logic need matching regression tests. Before a PR run `./test.sh`, `python3 scripts/check_localization.py`, `./build.sh` and `python3 scripts/package_source.py --check`.
- **Translations:** source texts are German (`String(localized:)` / SwiftUI literals). Add the English text to `Resources/en.lproj/Localizable.strings`; `scripts/check_localization.py` extracts all keys with the Swift compiler and fails on missing or unused entries. New languages: add `Resources/<lang>.lproj/Localizable.strings`, list the language in `CFBundleLocalizations` in `build.sh` and in `scripts/package_source.py`.
- State the origin of AI-generated contributions and the tests you actually ran. Don’t claim human review that did not happen.
