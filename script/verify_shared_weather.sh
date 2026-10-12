#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .prototype-build/weather/module-cache
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -parse-as-library -module-cache-path .prototype-build/weather/module-cache Fonsters/SharedWeatherSnapshot.swift script/verify_shared_weather.swift -o .prototype-build/weather/verify-weather
.prototype-build/weather/verify-weather
