#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly PROJECT_ROOT="${SCRIPT_DIR:h}"
readonly CONFIGURATION="${1:-Debug}"
readonly DERIVED_DATA_PATH="${PROJECT_ROOT}/.build/HostDerivedData"
readonly SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:--}"
readonly APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/Tilde.app"
readonly EXTENSION_PATH="${APP_PATH}/Contents/PlugIns/TildeQuickLook.appex"
readonly CLI_BINARY="${PROJECT_ROOT}/.build/${CONFIGURATION:l}/tilde-cli"
readonly BUNDLED_CLI="${APP_PATH}/Contents/Helpers/tilde"

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
  ARCHS=arm64 \
  CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
  build

if [[ ! -x "${CLI_BINARY}" ]]; then
  print -u2 "Tilde CLI not found at ${CLI_BINARY}"
  exit 1
fi
mkdir -p "${BUNDLED_CLI:h}"
cp "${CLI_BINARY}" "${BUNDLED_CLI}"
chmod 755 "${BUNDLED_CLI}"

# Xcode can update the SwiftPM resource bundle after signing the extension.
# Re-sign from the nested extension outward so its sealed resources match.
codesign --force \
  --preserve-metadata=entitlements,requirements,flags,runtime \
  --sign "${SIGNING_IDENTITY}" "${EXTENSION_PATH}"
codesign --force \
  --sign "${SIGNING_IDENTITY}" "${BUNDLED_CLI}"
codesign --force \
  --preserve-metadata=requirements,flags,runtime \
  --entitlements "${PROJECT_ROOT}/Host/App/Tilde.entitlements" \
  --sign "${SIGNING_IDENTITY}" "${APP_PATH}"

print "Built ${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/Tilde.app"
