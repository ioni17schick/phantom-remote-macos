#!/usr/bin/env python3
"""Check and package only public sources. Never walk private backup/asset folders."""
import argparse
import pathlib
import re
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
FILES = [
    '.gitignore', 'App.swift', 'Core.swift', 'Discovery.swift', 'Models.swift',
    'Views.swift', 'Updates.swift', 'make_icon.swift', 'build.sh', 'test.sh', 'README.md',
    'LICENSE', 'CONTRIBUTING.md', 'SECURITY.md', 'CHANGELOG.md',
    'Tests/RegressionTests.swift', '.github/workflows/ci.yml',
    'scripts/package_source.py', 'scripts/release.sh',
    '.github/workflows/release.yml', '.github/release-notes.md',
]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    # Detect common local identity/credential leaks. Examples use reserved test addresses.
    forbidden = [r'/' + r'Users/[^/\s]+/', r'Phantom\d+dB-[A-Z0-9]{8,}',
                 r'192\.168\.\d+\.\d+', r'-----BEGIN [A-Z ]*PRIVATE KEY-----',
                 r'gh[pousr]_[A-Za-z0-9]{20,}', r'sk-[A-Za-z0-9]{20,}']
    for name in FILES:
        path = ROOT / name
        if not path.is_file() or path.is_symlink():
            raise SystemExit(f'Missing or unsafe source: {name}')
        text = path.read_text()
        if any(re.search(pattern, text) for pattern in forbidden):
            raise SystemExit(f'Possible private data in {name}; inspect locally before publishing.')
    print(f'Publication check passed: {len(FILES)} explicitly selected source files.')
    if not args.check:
        dest = ROOT / 'dist' / 'phantom-remote-source-0.1.0-beta.zip'
        dest.parent.mkdir(exist_ok=True)
        with zipfile.ZipFile(dest, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for name in FILES:
                archive.write(ROOT / name, 'phantom-remote/' + name)
        print(dest)

if __name__ == '__main__':
    main()
