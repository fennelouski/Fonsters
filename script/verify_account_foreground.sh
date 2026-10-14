#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .prototype-build/accounts/module-cache
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -parse-as-library -swift-version 5 -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault -module-cache-path .prototype-build/accounts/module-cache Fonsters/ProtectedPlayPolicy.swift Fonsters/FonsterInterests.swift Fonsters/FonsterPrivateInterestResolver.swift Fonsters/Accounts/FonsterAccountClient.swift Fonsters/Accounts/FonsterAccountTaskState.swift script/verify_account_foreground.swift -o .prototype-build/accounts/verify-account-foreground
/usr/bin/python3 -c 'import subprocess; subprocess.run([".prototype-build/accounts/verify-account-foreground"], check=True, timeout=30)'
