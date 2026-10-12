#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .prototype-build/accounts/module-cache
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -parse-as-library -module-cache-path .prototype-build/accounts/module-cache Fonsters/ProtectedPlayPolicy.swift Fonsters/FonsterInterests.swift Fonsters/FonsterPrivateInterestResolver.swift script/verify_private_interest_gate.swift -o .prototype-build/accounts/verify-private-interest-gate
.prototype-build/accounts/verify-private-interest-gate
