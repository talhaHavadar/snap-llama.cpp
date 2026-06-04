#!/bin/sh
# Helpers for reinstalling the snap mid-task. Source from a task.yaml:
#   . "$SPREAD_PATH/tests/lib/install-snap.sh"
#
# All helpers honour $CHANNEL (defaults to latest/edge if unset).
set -eu

: "${CHANNEL:=latest/edge}"

install_snap() {
  snap install llama-cpp --channel="$CHANNEL" --devmode
}

install_component() {
  name="$1"
  snap install "llama-cpp+${name}" --channel="$CHANNEL"
}

remove_snap() {
  snap remove --purge llama-cpp || true
}
