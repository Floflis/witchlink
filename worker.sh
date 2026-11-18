#!/usr/bin/env bash
# Compatibility entry point for older Witchlink layouts.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec "$SCRIPT_DIR/wl" "$@"
