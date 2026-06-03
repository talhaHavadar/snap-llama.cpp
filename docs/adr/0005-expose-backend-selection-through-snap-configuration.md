# 5. Expose backend selection through snap configuration

Date: 2026-06-03

## Status

Accepted

## Context

[ADR-0004](0004-load-gpu-backends-via-ggml-backend-path-single-backend-per-invocation.md)
established that the wrapper script picks one GPU backend per
invocation. That leaves the question of how the user expresses their
preference.

Routing the choice through an environment variable alone
(`LLAMA_CPP_BACKEND=hip`) is a common shape, but it has gaps on a
snapd-managed system:

- It is not persistent. Users would need to remember to set it in every
  shell, every cron job, every systemd unit.
- It is not discoverable. There is no list of valid values without
  reading the wrapper script.
- It cannot be validated at the moment the user picks a value;
  typos surface as "no backend loaded" errors at first inference,
  far from the place where the mistake was made.

snapd already provides the right primitives for this kind of
per-snap configuration: `sudo snap set <name> key=value`, readable
with `snap get <name> [key]` from outside the snap and with
`snapctl get key` from inside it. A `configure` hook runs every time
the value changes and can reject invalid input synchronously, so the
`snap set` call itself fails with a clear message.

## Decision

Add a `backend` snap configuration key (values: `cpu | hip | cuda | auto`)
as the primary mechanism for backend selection.

- The wrapper reads the value via `snapctl get backend`.
- A `configure` hook at `snap/hooks/configure` validates the value at
  `snap set` time and rejects unknown values with a one-line error.
  On first install (when `snapctl get backend` returns empty), the hook
  seeds the default `auto` so `snap get llama-cpp backend` always
  prints something meaningful.
- The `LLAMA_CPP_BACKEND` env var is retained as a higher-priority
  override, mainly for one-off debugging and CI scenarios where
  persistent state is undesirable.

Precedence (highest first):

1. `LLAMA_CPP_BACKEND` env var
2. `snapctl get backend` (set via `snap set llama-cpp backend=…`)
3. Default: `auto` (probe `hip`, then `cuda`, fall back to CPU)

## Consequences

Positive:

- Persistent, discoverable, snap-idiomatic configuration. Users
  configure once with `sudo snap set llama-cpp backend=hip` and the
  setting survives reboots and refreshes.
- Typos are caught at `snap set` time by the `configure` hook, with a
  message naming the valid values.
- The env var still works for per-invocation overrides
  (`LLAMA_CPP_BACKEND=cpu llama-cpp cli …`), which is convenient for
  benchmarking and debugging.

Negative / cost:

- One extra hook to maintain. It is small (under 20 lines of POSIX sh)
  but reviewers and contributors must remember it exists.
- Two layered configuration surfaces (env var > snap config > default)
  must be documented in the README. The wrapper's `--help`-style
  output names both to keep them discoverable in-place.
- `snapctl get` adds a process spawn on every wrapper invocation.
  Negligible compared to model load time.
