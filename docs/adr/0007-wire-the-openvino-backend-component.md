# 7. Wire the OpenVINO backend component

Date: 2026-07-24

## Status

Accepted

Builds on [ADR-0002](0002-split-llama-cpp-snap-into-cpu-main-snap-and-gpu-backend-components.md),
[ADR-0003](0003-build-with-llama-use-system-ggml-to-share-libggml-across-main-snap-and-components.md),
and [ADR-0006](0006-wire-the-cuda-backend-component.md).

## Context

Upstream llama.cpp ships a `ggml-openvino` backend
(`ggml/src/ggml-openvino`, `-DGGML_OPENVINO=ON`) that offloads inference to
Intel CPUs, integrated/discrete GPUs, and NPUs via the
[OpenVINO](https://docs.openvino.ai/) runtime. Like HIP, CUDA, Vulkan, and
OpenCL it builds through the normal `ggml_add_backend_library()` path and
supports `GGML_BACKEND_DL=ON`, so it fits the same component shape as the
other GPU backends.

It differs from every existing backend in one respect: it does not link
against a library available from the Ubuntu archive. `find_package(OpenVINO
REQUIRED COMPONENTS Runtime Threading)` needs Intel's OpenVINO runtime,
which Intel distributes only as:

- A prebuilt Linux archive (`openvino_toolkit_ubuntu24_<ver>_x86_64.tgz` from
  `storage.openvinotoolkit.org`), **x86_64 only** — no `arm64`/`aarch64`
  tarball is published for any recent release.
- An APT repo (`apt.repos.intel.com/openvino`) whose `Release` file lists
  `Architectures: all 386 amd64` — again no `arm64`.

Both this repo's CI matrix and its `platforms:` stanza build for `amd64` and
`arm64`. Snapcraft does not support a per-platform `components:` declaration
(ADR-0006 flagged this same gap for CUDA-on-arm64), so there is no
first-class way to say "this component only exists on amd64."

## Decision

Add a `ggml-openvino` part shaped like `ggml-hip`/`ggml-cuda`/`ggml-vulkan`/
`ggml-opencl` for everything ggml's own CMake controls: same upstream
`source-tag`, the same standalone-files `sed`, `GGML_BACKEND_DL=ON`, and the
same `stage:` exclusions that drop the duplicate `libggml.so` /
`libggml-base.so` / headers / cmake config that `ggml-cpu` already owns.

Handle the runtime dependency and the arch gap explicitly in
`override-build`:

- If `$CRAFT_ARCH_BUILD_FOR != amd64`, print a message, `mkdir -p
  $CRAFT_PART_INSTALL`, and exit before ever invoking `craftctl default`.
  The part produces no files on arm64, so the `openvino` component simply
  ends up empty on that architecture's snap — no arm64 publish step needs
  editing, and the arm64 build doesn't fail.
- On amd64, download and unpack the OpenVINO runtime archive into the part's
  build directory, `export OpenVINO_DIR=<unpacked>/runtime/cmake` (the same
  variable upstream's `setupvars.sh` sets), then call `craftctl default` to
  run the normal cmake configure/build/install.
- After `craftctl default`, copy every `.so*` under `runtime/lib/intel64`
  and `runtime/3rdparty/tbb/lib` into `$CRAFT_PART_INSTALL/opt/openvino-libs`
  so the declarative `organize:` step can route them into the component.
  This mirrors upstream's own packaging in `.devops/openvino.Dockerfile`,
  which does the same blanket copy.
- Build/stage the same OpenCL headers/ICD-loader packages the `opencl` part
  uses, since `ggml-openvino`'s CMakeLists also does
  `find_package(OpenCL REQUIRED)` (used for its GPU/NPU inference paths).

`organize:` uses a glob (`usr/bin/libggml-openvino*.so`) rather than the
exact filename the other backends use, specifically so it doesn't fail when
the part legitimately produced zero matching files on arm64.

## Consequences

Positive:

- Intel CPU/GPU/NPU users get a snap-native install path (`llama-cpp+openvino`)
  with no new mechanism — same wrapper (`cli.sh`), same `configure` hook
  validation, same `auto` probe list, same publish-workflow glob as every
  other backend.
- amd64 CI and users are unaffected; arm64 CI still builds successfully, it
  just produces a component with no backend `.so` in it.

Negative / cost:

- The `openvino` component is not installable-and-useful on arm64. Today
  that's silent: `snap install llama-cpp+openvino` on arm64 would install an
  empty component, and `LLAMA_CPP_BACKEND=openvino` would then fail the
  wrapper's "component is not installed" check rather than a clearer
  "not supported on this architecture" message. If this proves confusing in
  practice, the fix is either a `platforms:` filter on the `openvino`
  component when snapcraft grows one, or a snap-store exclusion for arm64.
- The build downloads a large (~100+ MiB compressed) third-party archive
  over plain HTTPS from `storage.openvinotoolkit.org` rather than the Ubuntu
  archive, so supply-chain trust rests on Intel's CDN and TLS rather than
  `apt`/GPG package signing. No checksum pinning is done beyond TLS; a
  future hardening pass could pin a SHA256 for the specific `ov_full`
  version referenced in `snapcraft.yaml`.
- OpenVINO is large: the runtime alone (core + CPU/GPU/NPU plugins + all
  frontends + TBB) adds a sizeable component, similar in spirit to the CUDA
  component's size concerns already noted in ADR-0006.
