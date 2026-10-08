# 7. Publish a ROCm-specific Track

Date: 2026-10-06

## Status

Accepted.

## Context

The main snap is architectured to maintain multiple llama.cpp backends, one in each component.
Since users are already expected to know what component they'll need, another way to cut this is across multiple tracks, so instead of installing `llama-cpp+rocm --channel=latest/stable`, it'll be `llama-cpp --channel=rocm/stable`.

This decouples rocm-specific changes from the main snap, including amd64-only support, the possibility of adding a `default-provider` link to external dependencies, and even further partitioning of the snap into per-ISA components.

## Decision

Publish a single amd64 llama.cpp snap on the `rocm` track.
Build its HIP backend against `rocm-inference` and install `libggml-hip.so` in the main snap, not a component.
Mount the provider's ROCm tree through the `rocm` content plug and make both the CLI and server use it at runtime.
Select HIP for both `hip` and `auto`, rejecting other backend settings rather than falling back to CPU.

## Consequences

- Users will need to install from a different channel.
- Users will need to manually connect the ROCm runtime library interface: `sudo snap connect llama-cpp:rocm rocm-inference:runtime`
- The snap no longer produces `.comp` artifacts on this track, and the ROCm release workflow no longer needs a component upload or arm64 revision.
