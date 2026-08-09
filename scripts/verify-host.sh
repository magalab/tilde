#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly PROJECT_ROOT="${SCRIPT_DIR:h}"
readonly CONFIGURATION="${1:-Debug}"
readonly APP_PATH="${PROJECT_ROOT}/.build/HostDerivedData/Build/Products/${CONFIGURATION}/Tilde.app"
readonly APP_EXECUTABLE="${APP_PATH}/Contents/MacOS/Tilde"
readonly BUNDLED_CLI="${APP_PATH}/Contents/Helpers/tilde"
readonly EXTENSION_PATH="${APP_PATH}/Contents/PlugIns/TildeQuickLook.appex"
readonly EXTENSION_PLIST="${EXTENSION_PATH}/Contents/Info.plist"
readonly APP_LOCALIZATION_BUNDLE="${APP_PATH}/Contents/Resources/Tilde_TildeCore.bundle/Contents/Resources"
readonly EXTENSION_LOCALIZATION_BUNDLE="${EXTENSION_PATH}/Contents/Resources/Tilde_TildeCore.bundle/Contents/Resources"

cd "${PROJECT_ROOT}"

swift test
"${SCRIPT_DIR}/build-host.sh" "${CONFIGURATION}"

test -d "${APP_PATH}"
test -d "${EXTENSION_PATH}"
test -x "${APP_EXECUTABLE}"
test -x "${BUNDLED_CLI}"
test "$(stat -f '%i' "${APP_EXECUTABLE}")" != "$(stat -f '%i' "${BUNDLED_CLI}")"
"${APP_EXECUTABLE}" --verify-resources
readonly CLI_USAGE="$("${BUNDLED_CLI}" 2>&1 || true)"
[[ "${CLI_USAGE}" == Usage:\ tilde* ]]
codesign --verify --deep --strict "${APP_PATH}"

readonly APP_LOCALIZATIONS="$(
  plutil -extract CFBundleLocalizations json -o - "${APP_PATH}/Contents/Info.plist"
)"
test "${APP_LOCALIZATIONS}" = '["en","zh-Hans"]'
for resources_path in "${APP_LOCALIZATION_BUNDLE}" "${EXTENSION_LOCALIZATION_BUNDLE}"; do
  for language_code in en zh-Hans; do
    strings_path="${resources_path}/${language_code}.lproj/Localizable.strings"
    test -f "${strings_path}"
    plutil -lint "${strings_path}" >/dev/null
  done
done

readonly APP_SIGNED_ENTITLEMENTS="$(mktemp "${TMPDIR:-/tmp}/tilde-app-entitlements.XXXXXX")"
readonly EXTENSION_SIGNED_ENTITLEMENTS="$(mktemp "${TMPDIR:-/tmp}/tilde-quicklook-entitlements.XXXXXX")"
trap 'rm -f "${APP_SIGNED_ENTITLEMENTS}" "${EXTENSION_SIGNED_ENTITLEMENTS}"' EXIT
codesign -d --entitlements :- "${APP_PATH}" >"${APP_SIGNED_ENTITLEMENTS}" 2>/dev/null
codesign -d --entitlements :- "${EXTENSION_PATH}" >"${EXTENSION_SIGNED_ENTITLEMENTS}" 2>/dev/null

readonly SUPPORTED_TYPES="$(
  plutil -extract NSExtension.NSExtensionAttributes.QLSupportedContentTypes \
    json -o - "${EXTENSION_PLIST}"
)"
test "${SUPPORTED_TYPES}" = '["net.daringfireball.markdown"]'

readonly DATA_BASED_PREVIEW="$(
  plutil -extract NSExtension.NSExtensionAttributes.QLIsDataBasedPreview \
    raw -o - "${EXTENSION_PLIST}"
)"
test "${DATA_BASED_PREVIEW}" = "true"

readonly APP_IDENTIFIER="$(plutil -extract CFBundleIdentifier raw -o - "${APP_PATH}/Contents/Info.plist")"
readonly EXTENSION_IDENTIFIER="$(plutil -extract CFBundleIdentifier raw -o - "${EXTENSION_PLIST}")"
test "${EXTENSION_IDENTIFIER}" = "${APP_IDENTIFIER}.quicklook"

test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' Host/App/Tilde.entitlements)" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.files.user-selected.read-write' Host/App/Tilde.entitlements)" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' Host/QuickLook/TildeQuickLook.entitlements)" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "${APP_SIGNED_ENTITLEMENTS}")" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.files.user-selected.read-write' "${APP_SIGNED_ENTITLEMENTS}")" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "${EXTENSION_SIGNED_ENTITLEMENTS}")" = "true"

print "Verified SwiftPM tests, ${APP_PATH}, English/Chinese resources, signing, sandbox entitlements, and Markdown-only Quick Look registration."
