# 2. Split llama-cpp snap into CPU main snap and GPU backend components

Date: 2026-06-03

## Status

Accepted

## Context

The original snap layout built llama.cpp once with `-DGGML_HIP=ON` and
organised every produced file into a single component named `hip`
(`organize: "*": (component/hip)`). The main snap was effectively empty
(~16 KB) — installing `llama-cpp` on its own gave a wrapper script
pointing at paths that did not exist. The only useful install was the
parent snap plus the `hip` component, which carried both the binaries and
the HIP/ROCm runtime in a ~1 GB blob.

Two concrete problems followed from that:

1. Anyone without an AMD GPU got nothing usable from the snap. There was
   no way to fall back to a CPU build.
2. Adding a second GPU backend (CUDA) would have meant either doubling
   the size of the snap for every user, or shipping a parallel `+cuda`
   component that duplicated all the binaries again — both options scale
   badly.

Debian solves the same fan-out problem cleanly: one base `libggml0`
package carries the loader, the headers, and the CPU backends; per-GPU
backends live in their own `libggml0-backend-{hip,cuda,vulkan,…}`
packages that depend on `libggml0` and ship only their own
`libggml-<gpu>.so` plus the GPU vendor runtime. llama.cpp itself
(`llama.cpp-tools`) is one more package on top, depending on `libggml0`
and discovering backends at runtime.

## Decision

Mirror the Debian split in the snap.

- The **main snap** ships ggml (built with `GGML_BACKEND_DL=ON` and
  `GGML_CPU_ALL_VARIANTS=ON`) and llama.cpp (built with
  `LLAMA_USE_SYSTEM_GGML=ON`). All `llama-*` binaries, `libllama.so`,
  `libggml-base.so`, `libggml.so`, and every `libggml-cpu*.so` variant
  live here. The snap works on any x86_64 or arm64 machine without any
  component installed.
- A **`hip` component** carries only `libggml-hip.so` plus the ROCm
  runtime libraries (`libhipblas`, `librocblas`, etc.) needed to dlopen
  the backend. No llama.cpp binaries, no `libggml-base.so` duplicate.
- A **`cuda` component** is declared in `snapcraft.yaml` so the store
  metadata and wrapper are ready for it, but the build part itself is
  deferred to a follow-up so this round can ship without depending on
  CUDA being available in the core26 archive.

## Consequences

Positive:

- Installing the parent snap alone gives a functional CPU build.
- Adding new GPU backends (cuda, vulkan, …) is additive: a new part,
  a new `components:` entry, no changes to the main snap or to existing
  users.
- Snap and component sizes track the actual hardware needs of each
  install — CPU users do not download a GB of ROCm.

Negative / cost:

- Breaking change for current `llama-cpp+hip` users. Binaries move
  from inside the component into the main snap; any script invoking
  paths like
  `/snap/llama-cpp/components/<rev>/hip/usr/local/bin/llama-cli`
  directly stops working. Mitigated by bumping the version string and
  documenting in the README migration note.
- Snapcraft now runs multiple `ggml` CMake builds per invocation
  (one for the main snap, one per GPU component). CI time grows
  roughly linearly with the number of backends.
- The component build must use the **same upstream `source-tag`** as
  the main snap build for ABI compatibility — version bumps must
  update every part together. This concern is the subject of
  [ADR-0003](0003-build-with-llama-use-system-ggml-to-share-libggml-across-main-snap-and-components.md).
