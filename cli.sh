#!/usr/bin/env bash
set -ex
export COMPONENT="$SNAP_COMPONENTS/hip"
# Default OpenAI base path for llama.cpp HTTP server
export OPENAI_BASE_PATH="/v1"
# Add llama.cpp binaries
export PATH="$PATH:$COMPONENT/usr/local/bin"
# Add llama.cpp-built shared libraries
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$COMPONENT/usr/local/lib"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$COMPONENT/usr/local/bin"
# Add shared libraries added via staged debian packages
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$COMPONENT/usr/lib/$ARCH_TRIPLET"

llama-cli "$@"
