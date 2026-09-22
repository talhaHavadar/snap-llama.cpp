#!/usr/bin/env bash
set -euo pipefail

# Resolve the requested backend in precedence order:
#   1) LLAMA_CPP_BACKEND env var (per-invocation override)
#   2) snap config (snap set llama-cpp backend=…)
#   3) default: auto
resolve_request() {
  if [ -n "${LLAMA_CPP_BACKEND:-}" ]; then
    echo "$LLAMA_CPP_BACKEND"; return
  fi
  local cfg
  cfg="$(snapctl get backend 2>/dev/null || true)"
  if [ -n "$cfg" ]; then
    echo "$cfg"; return
  fi
  echo "auto"
}

choose_backend() {
  local req; req="$(resolve_request)"
  case "$req" in
    cpu)
      echo ""; return ;;
    hip|cuda|vulkan|opencl)
      if [ ! -f "$SNAP_COMPONENTS/$req/lib/ggml/backends/libggml-$req.so" ]; then
        echo "llama-cpp: backend='$req' selected but the $req component is not installed." >&2
        echo "  Install it: sudo snap install --devmode llama-cpp+$req" >&2
        echo "  Or change:  sudo snap set llama-cpp backend=auto" >&2
        exit 2
      fi
      echo "$req"; return ;;
    auto)
      for c in hip cuda vulkan opencl; do
        if [ -f "$SNAP_COMPONENTS/$c/lib/ggml/backends/libggml-$c.so" ]; then
          echo "$c"; return
        fi
      done
      echo ""; return ;;
    *)
      echo "llama-cpp: invalid backend='$req' (use cpu|hip|cuda|vulkan|opencl|auto)" >&2
      exit 2 ;;
  esac
}

backend="$(choose_backend)"
if [ -n "$backend" ]; then
  export GGML_BACKEND_PATH="$SNAP_COMPONENTS/$backend/lib/ggml/backends/libggml-$backend.so"
  export LD_LIBRARY_PATH="$SNAP_COMPONENTS/$backend/lib:${LD_LIBRARY_PATH:-}"
fi

if [ $# -eq 0 ]; then
  echo "Usage: llama-cpp <subcommand> [args...]"
  echo "Example: llama-cpp cli --help"
  echo
  echo "Available subcommands:"
  ls "$SNAP/bin/" | sed -n 's/^llama-/  /p'
  echo
  echo "Backend: ${backend:-cpu}"
  echo "  Configure persistently: sudo snap set llama-cpp backend={cpu,hip,cuda,vulkan,opencl,auto}"
  echo "  Override per-run:       LLAMA_CPP_BACKEND=... llama-cpp ..."
  exit 1
fi

cmd="$1"; shift
exec "$SNAP/bin/llama-$cmd" "$@"
