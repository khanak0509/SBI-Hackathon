#!/usr/bin/env bash
# Build debug APK, then print scan commands (run from SBI-Hackathon/backend).
set -euo pipefail
cd "$(dirname "$0")"
# fake_yono_lab -> lab_fake_sbi_app -> apk_ml_model -> backend
BACKEND="$(cd "../../.." && pwd)"

FLUTTER="${FLUTTER_HOME:-$HOME/development/flutter}/bin/flutter"
if [[ ! -x "$FLUTTER" ]]; then
  FLUTTER="$(command -v flutter || true)"
fi
if [[ -z "$FLUTTER" || ! -x "$FLUTTER" ]]; then
  echo "Flutter not found. Set FLUTTER_HOME or add flutter to PATH."
  exit 1
fi

# arm64-only avoids NDK/CMake "unknown target CPU armv7-a" on Apple Silicon hosts
"$FLUTTER" build apk --debug --target-platform android-arm64
APK="$(pwd)/build/app/outputs/flutter-apk/app-debug.apk"
echo ""
echo "Built: $APK"
echo ""
echo "From backend directory ($BACKEND), run:"
echo "  python3 apk_ml_model/scripts/model3_behavioral_engine.py \"$APK\""
echo "  python3 apk_ml_model/scripts/model2_drebin_validator.py \"$APK\""
