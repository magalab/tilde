#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIR="${0:A:h}"
readonly PROJECT_ROOT="${SCRIPT_DIR:h}"
readonly DEFAULT_BINARY="${PROJECT_ROOT}/.build/release/tilde"
readonly INSTALL_DIR="${HOME}/.local/bin"
readonly INSTALL_PATH="${INSTALL_DIR}/tilde"

CLI_SOURCE="${TILDE_CLI_PATH:-${DEFAULT_BINARY}}"
if [[ ! -x "${CLI_SOURCE}" ]]; then
    print -u2 "Tilde CLI not found at ${CLI_SOURCE}. Build it with: swift build -c release --product tilde"
    exit 1
fi

mkdir -p "${INSTALL_DIR}"
cp "${CLI_SOURCE}" "${INSTALL_PATH}"
chmod 755 "${INSTALL_PATH}"
print "Installed ${INSTALL_PATH}"
print "Ensure ${INSTALL_DIR} is on PATH, then run: tilde file.txt"
