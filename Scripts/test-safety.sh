#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/lightsout-safety-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -o "$test_dir/safety-tests" \
  LightsOut/Services/DisplayPreferenceStore.swift \
  LightsOut/Services/DisplayReconciler.swift \
  LightsOut/Services/DisplaySafetyPolicy.swift \
  LightsOut/Services/GammaUpdateService.swift \
  LightsOut/Services/DisplayStateStore.swift \
  LightsOut/DisplayInfoModel.swift \
  LightsOut/Errors/ConfigurationError.swift \
  Tests/SafetyRegression.swift
"$test_dir/safety-tests"
