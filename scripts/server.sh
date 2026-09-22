#!/usr/bin/env bash
set -euo pipefail

# Add additional command line arguments as configured
SERVER_OPTS=()
read -r -a SERVER_OPTS <<< "$(snapctl get server-opts)";
exec "${SNAP}"/bin/cli-wrapper server "${SERVER_OPTS[@]}"
