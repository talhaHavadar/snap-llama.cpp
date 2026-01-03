#!/usr/bin/env bash
set -e
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

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: llama-cpp <llama binary> [arguments...]"
    echo "
Example: llama-cpp cli --help
This prints help output of llama-cli.
See available llama binaries:

$(basename -a $COMPONENT/usr/local/bin/llama-*)
    "
    exit 1
fi

command="$1"

# Shift to remove the first argument, leaving only the remaining arguments
shift
full_command="llama-${command}"

exec "$full_command" "$@"
