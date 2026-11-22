#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p .build/tests
xcrun swiftc -swift-version 6 -strict-concurrency=complete -warnings-as-errors -parse-as-library \
  -target "$(uname -m)-apple-macos14" Models.swift Discovery.swift Updates.swift Core.swift Tests/RegressionTests.swift -o .build/tests/regression
.build/tests/regression
