# 4. Load GPU backends via GGML_BACKEND_PATH (single backend per invocation)

Date: 2026-06-03

## Status

Accepted

## Context

With the snap split into a CPU main snap plus per-vendor GPU components
([ADR-0002](0002-split-llama-cpp-snap-into-cpu-main-snap-and-gpu-backend-components.md)),
the runtime question is: how does `llama-cli` discover and load the
`libggml-<gpu>.so` that lives inside a separately-mounted snap
component?

Upstream's loader lives in `ggml/src/ggml-backend-reg.cpp`. With
`GGML_BACKEND_DL=ON`, `ggml_backend_load_all()` (line 543) calls
`ggml_backend_load_best()` (line 461) for each known backend name. That
function scans, in order:

1. The compile-time macro `GGML_BACKEND_DIR` (single directory).
2. The executable directory (`/proc/self/exe`'s dirname).
3. The current working directory.

After all the named-backend lookups it reads the env var
`GGML_BACKEND_PATH` (line 570) and, if set, calls
`ggml_backend_load(backend_path)` on it. **That env var accepts exactly
one file path — it is not colon-list-aware.**

Snap components live at distinct read-only mount paths
(`/snap/llama-cpp/components/<rev>/<name>/`), unreachable from any of
the three compile-time-or-process-local search dirs. So the only stock
upstream hook for pointing the loader at a component file is
`GGML_BACKEND_PATH`, and it's a single-file knob.

For true simultaneous AMD-plus-NVIDIA in one process we would need
either a small upstream patch (make `GGML_BACKEND_PATH` accept a
colon-separated list, ~10 lines) or a writable backend directory
composed at runtime via snap `layout:` and the wrapper. Both add
ongoing maintenance cost.

llama.cpp's `-dev`/`--device <dev1,dev2,…>` CLI flag
(`common/arg.cpp:2249`, env `LLAMA_ARG_DEVICE`) is orthogonal: it picks
among devices reported by backends already loaded. It does not
itself dlopen anything.

## Decision

Use the stock upstream mechanism and accept "one GPU backend per
invocation" as a documented limitation.

- Compile the main snap with
  `-DGGML_BACKEND_DIR=/snap/llama-cpp/current/lib/ggml/backends`. The
  CPU variants live there in the main snap, so they are always
  discovered without any env var. The `current` symlink is managed by
  snapd and resolves to the active revision, so the path survives
  refreshes.
- The wrapper script sets `GGML_BACKEND_PATH` to the absolute path of
  one component's `libggml-<gpu>.so` based on the resolved backend
  selection (see
  [ADR-0005](0005-expose-backend-selection-through-snap-configuration.md)).
  It also extends `LD_LIBRARY_PATH` with the component's `lib/` so the
  vendor runtime resolves.
- Same-vendor multi-GPU (two NVIDIA cards, two AMD cards) continues to
  work as upstream documents — one backend loaded, `--device` selects
  among the cards.
- True simultaneous AMD+NVIDIA is deferred. A future ADR can supersede
  this one when the patch lands upstream or when the cost of the
  workaround is justified.

## Consequences

Positive:

- No downstream patch to llama.cpp. The snap works on stock upstream
  source at any tag that supports `GGML_BACKEND_DL`.
- The wrapper logic is small enough to fit in `cli.sh` without a
  helper binary.
- The compile-time `GGML_BACKEND_DIR` keeps the CPU path frictionless
  even with no env vars set — no surprises for users running
  `llama-cpp` without any component installed.

Negative / cost:

- Dual-vendor systems must switch backends per invocation (env var or
  `snap set llama-cpp backend=…`). Documented in the README. The
  follow-up patch is noted in the plan and ADR text for whoever picks
  it up.
- `GGML_BACKEND_DIR` is hardcoded to the snap name. Renaming the snap
  (unlikely) requires a rebuild — call out in `snapcraft.yaml`.
- The wrapper must `-f` test the component `.so` before exporting
  `GGML_BACKEND_PATH`; otherwise an empty path crashes the loader.
