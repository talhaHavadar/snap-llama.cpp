# Snap of llama.cpp

[![llama-cpp](https://snapcraft.io/llama-cpp/badge.svg)](https://snapcraft.io/llama-cpp)

`llama.cpp` packaged as a snap. The main snap ships a CPU build that runs
anywhere; optional snap components add GPU backends.

## Install

```bash
# Main snap (CPU, always required)
sudo snap install --edge --devmode llama-cpp

# Optional: add the AMD GPU (HIP/ROCm) backend
sudo snap install --edge --devmode llama-cpp+hip

# Optional: NVIDIA backend — reserved for a follow-up release, not yet built.
# sudo snap install --edge --devmode llama-cpp+cuda
```

## Configure the backend

The wrapper picks one GPU backend per invocation. The choice is read from
(highest priority first):

1. `LLAMA_CPP_BACKEND` env var — for one-off overrides.
2. Snap config (`snap set llama-cpp backend=…`) — persistent across reboots
   and refreshes.
3. Default: `auto` — probe `hip`, then `cuda`, fall back to CPU.

```bash
# Persistent: set once, applies to every future invocation
sudo snap set llama-cpp backend=hip
snap get llama-cpp backend           # -> hip

# Per-invocation override (no config change)
LLAMA_CPP_BACKEND=cpu llama-cpp cli --list-devices
```

Valid values: `cpu`, `hip`, `cuda`, `auto`. Invalid values are rejected at
`snap set` time by the configure hook with a clear error.

## Usage

The wrapper appends its first argument to `llama-`, so `llama-cpp cli`
exec's `llama-cli`, `llama-cpp server` exec's `llama-server`, etc.

```bash
# AMD GPU users: join the render/video groups so the snap can access /dev/kfd
sudo usermod -aG video,render "$USER"
# log out and back in for group changes to take effect

# Server
llama-cpp server

# Run inference from a Hugging Face model
llama-cpp cli -hf hugging-quants/Llama-3.2-1B-Instruct-Q8_0-GGUF

# List devices the loaded backend sees
llama-cpp cli --list-devices
```

## Architecture

The snap is split into a CPU main snap plus optional GPU backend snap
components, mirroring how Debian packages `ggml` and `llama.cpp`:

- Main snap: `ggml` (built with `GGML_BACKEND_DL=ON GGML_CPU_ALL_VARIANTS=ON`)
  - `llama.cpp` (built with `LLAMA_USE_SYSTEM_GGML=ON`).
- `hip` component: only `libggml-hip.so` and the ROCm runtime libs.
- `cuda` component: same shape, deferred.

The rationale and trade-offs are recorded as ADRs under
[`docs/adr/`](docs/adr/). Start with
[ADR-0002](docs/adr/0002-split-llama-cpp-snap-into-cpu-main-snap-and-gpu-backend-components.md).

## Building

```bash
snapcraft pack
# produces:
#   llama-cpp_<version>_<arch>.snap         (main snap, small)
#   llama-cpp+hip_<version>_<arch>.comp     (HIP component, large)
```

Local install for testing:

```bash
sudo snap install --devmode --dangerous llama-cpp_<version>_<arch>.snap
sudo snap install --devmode --dangerous llama-cpp+hip.comp
```

## Migrating from earlier versions

Earlier releases bundled every binary inside the `hip` component, so the
main snap was empty. Starting with `b9222-2` the binaries live in the main
snap and the component only carries GPU code. Any script that referenced
absolute paths like `/snap/llama-cpp/components/<rev>/hip/usr/local/bin/llama-cli`
must switch to the wrapper (`llama-cpp cli …`) or use `$PATH`-based
invocation. Standard `llama-cpp …` usage and `snap run llama-cpp …` are
unaffected.
