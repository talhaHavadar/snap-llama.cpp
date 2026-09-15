# Snap of llama.cpp

[![llama-cpp](https://snapcraft.io/llama-cpp/badge.svg)](https://snapcraft.io/llama-cpp)
[![Spread](https://github.com/talhaHavadar/snap-llama.cpp/actions/workflows/spread.yml/badge.svg)](https://github.com/talhaHavadar/snap-llama.cpp/actions/workflows/spread.yml)

`llama.cpp` packaged as a snap. The main snap ships a CPU build that runs
anywhere; optional snap components add GPU backends.

## Install

```bash
# Main snap (CPU, always required)
sudo snap install --edge --devmode llama-cpp

# Optional: add the AMD GPU (HIP/ROCm) backend
sudo snap install --edge --devmode llama-cpp+hip

# Optional: add the NVIDIA GPU (CUDA) backend
sudo snap install --edge --devmode llama-cpp+cuda

# Optional: add the Vulkan GPU backend (Intel, AMD, etc.)
sudo snap install --edge --devmode llama-cpp+vulkan

# Optional: add the OpenCL GPU backend (Adreno, Mali, etc.)
sudo snap install --edge --devmode llama-cpp+opencl

# Optional: add the Intel CPU/GPU/NPU (OpenVINO) backend — amd64 only
sudo snap install --edge --devmode llama-cpp+openvino
```

## Configure the backend

The wrapper picks one GPU backend per invocation. The choice is read from
(highest priority first):

1. `LLAMA_CPP_BACKEND` env var — for one-off overrides.
2. Snap config (`snap set llama-cpp backend=…`) — persistent across reboots
   and refreshes.
3. Default: `auto` — probe `hip`, `cuda`, `vulkan`, `opencl`, `openvino` in
   that order, fall back to CPU.

```bash
# Persistent: set once, applies to every future invocation
sudo snap set llama-cpp backend=hip
snap get llama-cpp backend           # -> hip

# Per-invocation override (no config change)
LLAMA_CPP_BACKEND=cpu llama-cpp cli --list-devices
```

Valid values: `cpu`, `hip`, `cuda`, `vulkan`, `opencl`, `openvino`, `auto`.
Invalid values are rejected at `snap set` time by the configure hook with a
clear error.

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
- `cuda` component: only `libggml-cuda.so` and the CUDA runtime libs.
- `vulkan` component: only `libggml-vulkan.so` and the Vulkan loader.
- `opencl` component: only `libggml-opencl.so` and the OpenCL ICD loader.
- `openvino` component: only `libggml-openvino.so` and the OpenVINO
  runtime/threading libs. amd64 only — Intel does not publish an arm64
  OpenVINO runtime archive.

The rationale and trade-offs are recorded as ADRs under
[`docs/adr/`](docs/adr/). Start with
[ADR-0002](docs/adr/0002-split-llama-cpp-snap-into-cpu-main-snap-and-gpu-backend-components.md).

## Building

```bash
snapcraft pack
# produces:
#   llama-cpp_<version>_<arch>.snap         (main snap, small)
#   llama-cpp+hip.comp                      (HIP component, large)
#   llama-cpp+cuda.comp                     (CUDA component, large)
#   llama-cpp+vulkan.comp                   (Vulkan component)
#   llama-cpp+opencl.comp                   (OpenCL component)
#   llama-cpp+openvino.comp                 (OpenVINO component, amd64 only)
```

Local install for testing:

```bash
sudo snap install --devmode --dangerous llama-cpp_<version>_<arch>.snap
sudo snap install --devmode --dangerous llama-cpp+hip.comp
sudo snap install --devmode --dangerous llama-cpp+cuda.comp
```

## Migrating from earlier versions

Earlier releases bundled every binary inside the `hip` component, so the
main snap was empty. Starting with `b9222-2` the binaries live in the main
snap and the component only carries GPU code. Any script that referenced
absolute paths like `/snap/llama-cpp/components/<rev>/hip/usr/local/bin/llama-cli`
must switch to the wrapper (`llama-cpp cli …`) or use `$PATH`-based
invocation. Standard `llama-cpp …` usage and `snap run llama-cpp …` are
unaffected.
