# 6. Wire the CUDA backend component

Date: 2026-06-03

## Status

Accepted

Builds on [ADR-0002](0002-split-llama-cpp-snap-into-cpu-main-snap-and-gpu-backend-components.md)
and [ADR-0003](0003-build-with-llama-use-system-ggml-to-share-libggml-across-main-snap-and-components.md).

## Context

[ADR-0002](0002-split-llama-cpp-snap-into-cpu-main-snap-and-gpu-backend-components.md)
introduced the `cuda` component as a declared-but-unwired placeholder.
The wrapper (`cli.sh`), the `configure` hook, and the snap config
plumbing already treat `cuda` as a first-class case; only the build
part was missing.

Debian splits the same library the same way: `libggml0` ships the
loader and CPU backends, and `libggml0-backend-cuda` ships just
`libggml-cuda.so` and depends on `libggml0`. The Debian rules at
`/home/talha/sandbox/ggml-cuda/debian/rules` document the CMake flags
needed on top of our shared baseline (`GGML_BACKEND_DL=ON`,
`GGML_NATIVE=OFF`): `-DGGML_CPU=OFF -DGGML_CUDA=ON`, with
`nvidia-cuda-toolkit-gcc` as the build-side host-compiler bridge for
nvcc.

A second wrinkle is `CMAKE_CUDA_ARCHITECTURES`. ggml's CMake defaults
either to `native` (when `GGML_NATIVE=ON`, which we turn off) or to a
pre-Turing list (`50;61;70;75`). Neither is right for a CI-built snap
that must run on a range of modern NVIDIA cards. We need to pin the
list explicitly.

A third wrinkle is the publish workflow. The existing step at
`.github/workflows/snap.yml` hard-coded the `hip` component name in the
`snapcraft upload --component hip=…` invocation. Adding `cuda` (or any
future backend) by hard-coding a second `--component cuda=…` works but
does not scale.

## Decision

Add a `ggml-cuda` build part that mirrors the existing `ggml-hip` part:

- Same upstream `source-tag` for ABI compatibility per
  [ADR-0003](0003-build-with-llama-use-system-ggml-to-share-libggml-across-main-snap-and-components.md).
- Same `override-pull` sed to flip `GGML_STANDALONE ON` → `OFF`.
- Same `stage:` exclusions to drop the duplicate `libggml.so`,
  `libggml-base.so`, headers, cmake configs, and pkgconfig — `ggml-cpu`
  already owns these and the CUDA-built copies would collide.
- Same `organize:` shape: route `libggml-cuda.so` and the CUDA runtime
  closure into `(component/cuda)/lib/`.

CUDA-specific differences:

- `build-packages: [nvidia-cuda-toolkit, nvidia-cuda-toolkit-gcc]` for
  nvcc and a host compiler nvcc accepts.
- `stage-packages: [libcublas12, libcudart12, libcusparse12, libgomp1]`
  for the runtime closure the catch-all organize routes into the
  component.
- `-DGGML_CUDA=ON -DGGML_CPU=OFF` instead of `-DGGML_HIP=ON`.
- `-DCMAKE_CUDA_ARCHITECTURES=70;75;80;86;89;90` (Volta through
  Hopper) — explicit so the build works on any CI runner regardless of
  hardware, and broad enough to cover any consumer NVIDIA card from
  2018 onward.

Replace the hard-coded `--component hip=…` in
`.github/workflows/snap.yml` with a glob over `llama-cpp+*.comp` that
derives each component name from the filename. Adding a fourth or
fifth component (vulkan, sycl, …) in future then needs no workflow
change.

## Consequences

Positive:

- NVIDIA GPU users get a snap-native install path that matches the
  Debian pattern users are already familiar with.
- The split, the wrapper logic, and the snap config were already
  cuda-shaped — this ADR turns the existing design on rather than
  introducing new structure.
- The publish step is now backend-agnostic: future GPU backend
  components drop in by adding one part to `snapcraft.yaml` and one
  `components:` entry, with no workflow edits.

Negative / cost:

- The CUDA component is large (hundreds of MB once cuBLAS and friends
  are bundled) and slow to build. Combined with the existing HIP
  build, the matrix runners get closer to GitHub's 14 GB disk limit
  and to the soft wall-clock cap. ADR-0002 already flagged this and
  noted the escape hatch: splitting `ggml-hip` and `ggml-cuda` into
  separate matrix jobs.
- `nvidia-cuda-toolkit` on arm64 in the Ubuntu archive is sparser than
  on amd64. If the arm64 build fails for that reason, the
  short-term workaround is dropping arm64 from the matrix; the
  longer-term fix is gating the part by `build-on:` and dropping the
  `cuda` artefact from the arm64 publish step (snapcraft does not
  currently support a per-platform `components:` declaration).
- CUDA is non-free. The Ubuntu archive carries the runtime libraries
  under standard terms but downstream redistribution must respect the
  NVIDIA EULA.
