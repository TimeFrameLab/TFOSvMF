#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="${1:-UPDATE}"
UPDATE_PATTERN='^UPDATE/[[:space:]]*[A-Za-z0-9][A-Za-z0-9 ._&()/#-]*$'

if [[ $# -gt 1 ]] || { [[ "$COMMAND" != "UPDATE" ]] && [[ ! "$COMMAND" =~ $UPDATE_PATTERN ]]; }; then
  echo "Usage: ./update.sh [UPDATE/<AKA>-<AKA>-...]" >&2
  exit 2
fi

exec bash "$SCRIPT_DIR/fund_update.sh" "$COMMAND"
