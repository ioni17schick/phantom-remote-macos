#!/usr/bin/env python3
"""Extract every localizable string via the Swift compiler and verify the English table covers it."""
import glob, json, os, pathlib, re, subprocess, sys, tempfile
ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = ["Models.swift", "Discovery.swift", "Updates.swift", "Core.swift", "Views.swift", "App.swift"]
# Keys that are identical in every language (symbols, format-only strings, internal identifiers).
NEUTRAL = re.compile(r"^([a-z0-9.]+|[A-Z][a-z]+[A-Z][a-z]+|%[@d]|%lld( %@)?|%@ · %@|–|dB|Phantom Remote)$")
def table(path):
    text = path.read_text(encoding="utf-8")
    return dict(re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', text, re.M))
def main():
    with tempfile.TemporaryDirectory() as out:
        cmd = ["xcrun", "swiftc", "-swift-version", "6", "-parse-as-library", "-target", "arm64-apple-macos14",
               "-emit-localized-strings", "-emit-localized-strings-path", out, "-c", *[str(ROOT / s) for s in SOURCES],
               "-module-name", "PhantomRemote"]
        subprocess.run(cmd, cwd=out, check=True, stdout=subprocess.DEVNULL)
        keys = set()
        for f in glob.glob(os.path.join(out, "*.stringsdata")):
            for entries in json.load(open(f)).get("tables", {}).values():
                keys.update(e["key"] for e in entries)
    en = table(ROOT / "Resources/en.lproj/Localizable.strings")
    missing = sorted(k for k in keys if k not in en and not NEUTRAL.match(k))
    unused = sorted(k for k in en if k not in keys)
    for k in missing: print("MISSING en:", k)
    for k in unused: print("UNUSED en:", k)
    for k, v in en.items():
        if sorted(re.findall(r"%(?:lld|@|d)", k)) != sorted(re.findall(r"%(?:lld|@|d)", v)):
            print("PLACEHOLDER MISMATCH:", k); missing.append(k)
    print(f"Localization check: {len(keys)} keys, {len(en)} English entries, {len(missing)} problems, {len(unused)} unused.")
    sys.exit(1 if missing or unused else 0)
if __name__ == "__main__":
    main()
