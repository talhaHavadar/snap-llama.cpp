# Snap of llama.cpp

[![llama-cpp](https://snapcraft.io/llama-cpp/badge.svg)](https://snapcraft.io/llama-cpp)

llama.cpp packaged as snap with different backends as snap components.

## Building

```bash
snapcraft pack
# this should produce llama-cpp_<version>_<arch>.snap and llama-cpp+<backend/component>.comp
# Example:
# -rw-r--r-- 1 talha.can.havadar@canonical.com root     16384 Jan  3 23:25 llama-cpp_0.1_amd64.snap
# -rw-r--r-- 1 talha.can.havadar@canonical.com root 832348160 Jan  3 23:25 llama-cpp+hip.comp
```

## Install

```bash
# install llama-cpp with HIP backend
sudo snap install --devmode --edge llama-cpp+hip
```

### Local installs

```bash
sudo snap install --devmode --dangerous llama-cpp_0.1_amd64.snap
sudo snap install --devmode --dangerous llama-cpp+hip.comp
```

## Usage

Currently `llama-cpp` command, installed with the snap, pipes the first argument
at the end of `llama-` so if you run `llama-cpp cli` then it will execute `llama-cli` binary.

```bash
# Make sure the current user in groups `render` and `video`
sudo adduser $USER video
sudo adduser $USER render

# Simple server Example
llama-cpp server

# loading a model and running llama-cpp cli
llama-cpp cli -hf hugging-quants/Llama-3.2-1B-Instruct-Q8_0-GGUF
```
