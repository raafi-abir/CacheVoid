# CacheVoid Codebase Audit Report

## High-level assessment
This repository is a lightweight Android Magisk/KernelSU module that periodically clears app cache and can be triggered manually. The architecture is simple and workable, but there are reliability, safety, and maintainability issues that should be addressed before adding major new features.

## What to fix first (highest priority)

1. **Unsafe glob handling and unquoted paths in deletion routines**  
   Several scripts use patterns like `find $dir/* -delete` and `du -cs $dir` without robust quoting/`--` guards. If a glob expands unexpectedly (or does not expand), behavior can be inconsistent and potentially dangerous.

2. **Fragile process management**  
   Service start/stop logic relies on `ps | grep` matching, which is error-prone. PID tracking is partly implemented but not used as the sole source of truth.

3. **Broken/ambiguous cleaner invocation path**  
   `action.sh` checks for `/system/bin/cleaner` but then runs `cleaner` from PATH. This can fail depending on shell environment and mount timing.

4. **Insufficient error handling/logging guarantees**  
   Many operations ignore command failures (e.g., `find`, `du`, `sed`, `bc`) and continue silently, making support/debugging harder.

5. **Concurrency and lock protection missing**  
   Manual trigger and scheduled trigger can overlap. There is no lockfile/flock strategy to prevent concurrent cleanup runs.

## Improvements by area

### 1) Reliability and correctness
- Add strict shell guardrails in core scripts:
  - `set -u` (or careful default expansions) and predictable IFS.
  - explicit checks for required binaries (`du`, `find`, `bc`, busybox).
- Replace `ps|grep` process discovery with:
  - PID file validation (`kill -0 "$pid"`) and fallback scan only if missing.
- Replace arithmetic pipeline with safer fallback:
  - if `bc` missing, compute totals in shell loop.
- Standardize paths and avoid mixing `/data/adb/modules` and lite/ksu variants ad hoc.

### 2) Safety
- Use explicit allowlist deletion helper:
  - Validate target roots before deleting.
  - Use `find "$path" -mindepth 1 -xdev -delete` (or controlled recursion) instead of brittle globs.
- Protect against empty/failed expansions:
  - skip unreadable/nonexistent dirs gracefully and log counts.

### 3) Observability
- Make logs structured enough for support:
  - start/end timestamps, run mode (`manual|auto|boot`), total reclaimed KB/MB, duration, error count.
- Keep one stable state file (JSON or key-value) in `/data/adb/cleaner/run/` for UI/status and debugging.

### 4) Maintainability
- Deduplicate duplicate logic currently split between `cleaner` and `cleaner.service`.
- Move shared functions into one library script (e.g., `cleaner/lib.sh`) sourced by both entrypoints.
- Add a shell linter workflow (e.g., `shellcheck`) and basic CI gate.

## Feature ideas worth adding

1. **Per-app exclusion list (highest user value)**
- Config file such as `/data/adb/cleaner/exclude.list`.
- Skip selected package names (games/offline maps) to avoid unwanted cache deletion.

2. **Configurable thresholds and schedule**
- User-editable settings file:
  - `SIZE_LIMIT_KB=...`
  - `CRON_SCHEDULE="0 */6 * * *"`
- Validate values and auto-heal to defaults when invalid.

3. **Dry-run mode + reclaimed-space report**
- `cleaner --dry-run` prints candidate targets and estimated reclaimed size.
- After real run, store metrics (before/after/reclaimed).

4. **Battery/charging and idle-aware cleaning**
- Optional condition checks (charging state, screen off, idle window).
- Avoid heavy I/O during active use.

5. **Notification integration**
- Optional terminal notification/log summary after each run.
- Keep module.prop description updates, but make them concise and deterministic.

## Suggested implementation order

1. Refactor deletion + quoting + lockfile.
2. Harden PID/process management and command dependency checks.
3. Add config file parsing/validation.
4. Add exclusion list.
5. Add dry-run/metrics.
6. Add CI lint/test checks.

## Quick quality checklist for next PR
- [ ] No unquoted path expansions in destructive commands.
- [ ] Single-run lock prevents overlap.
- [ ] Service lifecycle uses PID file with `kill -0` validation.
- [ ] `shellcheck` passes on all `.sh` files.
- [ ] Manual and scheduled modes share the same cleanup core.
- [ ] Feature config documented in README with examples.
