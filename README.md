# Snap of llama.cpp

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
sudo snap install llama-cpp+hip
```

### Local installs

```bash
sudo snap install --devmode --dangerous llama-cpp_0.1_amd64.snap
sudo snap install --devmode --dangerous llama-cpp+hip.comp
```
