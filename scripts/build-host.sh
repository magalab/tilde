#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly PROJECT_ROOT="${SCRIPT_DIR:h}"
readonly CONFIGURATION="${1:-Debug}"
readonly DERIVED_DATA_PATH="${PROJECT_ROOT}/.build/HostDerivedData"
readonly SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:--}"

cd "${PROJECT_ROOT}"

if [[ ! -f "${PROJECT_ROOT}/AppIcon.icns" || "${PROJECT_ROOT}/Assets/TildeAppIcon.png" -nt "${PROJECT_ROOT}/AppIcon.icns" ]]; then
  "${SCRIPT_DIR}/create-icon.sh"
fi

# SwiftPM remains the source/dependency build graph. The Xcode project only
# packages its products into the macOS app and Quick Look extension bundles.
swift build -c "${CONFIGURATION:l}"

xcodebuild \
  -quiet \
  -project Host/TildeHost.xcodeproj \
  -scheme TildeHost \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
  build

print "Built ${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/Tilde.app"
