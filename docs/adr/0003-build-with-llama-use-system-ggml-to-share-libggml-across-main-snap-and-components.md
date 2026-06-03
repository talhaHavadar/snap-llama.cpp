# 3. Build with LLAMA_USE_SYSTEM_GGML to share libggml across main snap and components

Date: 2026-06-03

## Status

Accepted

## Context

[ADR-0002](0002-split-llama-cpp-snap-into-cpu-main-snap-and-gpu-backend-components.md)
splits the snap into a CPU main snap and GPU backend components. For the
split to work at runtime, the component-shipped `libggml-<gpu>.so` and
the main-snap-shipped `libggml-base.so` must be ABI-compatible: the GPU
backend `.so` is dlopen'd into the same process as `libggml-base.so` and
calls into its registry. A struct layout difference or a renamed
internal symbol between the two builds is enough to crash the process at
first inference call.

The most reliable way to guarantee ABI compatibility is to build all the
ggml libraries from the same source revision in the same snapcraft
invocation, and have llama.cpp consume that ggml rather than the copy it
carries in its own git submodule.

Upstream llama.cpp's CMake already supports this — Debian's
`llama.cpp` packaging relies on it. Setting `-DLLAMA_USE_SYSTEM_GGML=ON`
disables the in-tree ggml build and switches to
`find_package(ggml REQUIRED)`, which resolves against an installed
`ggml-config.cmake`.

## Decision

Split the snapcraft build into three CMake parts that all pull from the
same upstream `source-tag`:

1. `ggml-cpu` — builds the `ggml/` subdirectory of llama.cpp standalone
   with `GGML_BACKEND_DL=ON`, `GGML_CPU_ALL_VARIANTS=ON`, and stages
   the full install tree (libs + headers + `ggml-config.cmake`).
2. `llama-cpp` — `after: [ggml-cpu]`, builds the top-level llama.cpp
   with `-DLLAMA_USE_SYSTEM_GGML=ON`. `find_package(ggml REQUIRED)`
   resolves against the staged tree from part 1.
3. `ggml-hip` (and later `ggml-cuda`) — builds the same `ggml/` subdir
   again from the same `source-tag` with only the GPU backend enabled
   (`GGML_CPU=OFF GGML_HIP=ON`). Stages only `libggml-<gpu>.so` plus
   the GPU vendor runtime into the component, primes away the duplicate
   `libggml-base.so` and friends.

All parts pin to the same `source-tag` (currently `b9222`). Bumping
the snap version means bumping the tag in every part in lock-step.

## Consequences

Positive:

- ABI compatibility is guaranteed by construction: every `ggml` object
  in the final artefacts comes from the same git commit.
- The pattern mirrors Debian's packaging exactly, so anyone familiar
  with the Debian layout finds the snap's structure unsurprising. Patches
  and learnings transfer in both directions.
- llama.cpp's bundled ggml submodule isn't built, so the `llama-cpp`
  part is faster and smaller.

Negative / cost:

- Version bumps are a coordinated change across three `source-tag`
  fields in `snapcraft.yaml`. A linter or pre-commit check would catch
  drift; without one, reviewers need to watch for it. A renovate rule
  could automate this if the cost ever becomes annoying.
- Snapcraft runs ggml's CMake configure three times per build (twice
  if only HIP is wired). CI cost scales linearly with the number of
  GPU backends.
- The `prime:` filters on the GPU component parts are load-bearing:
  without them, a component's local copy of `libggml-base.so` ends up
  in the component and collides with the main snap's at dlopen time.
  Reviewers must check the `prime:` block of any new GPU part.
