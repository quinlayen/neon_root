#!/bin/bash
# ============================================================
#  Neon Root — multi-watcher process helpers (stub + kill API)
#  Sourceable. bash 3.2 safe.
#
#  Paths (under metroplex root = NEON_ROOT or ROOT):
#    .bin/nr_watcher_<job_id>     executable
#    .watchers/<job_id>.pid       pidfile
#    .watchers/<job_id>.down      slain / down flag
#
#  spawn_watcher is a no-op stub until real watcher binaries land.
#  kill_watcher / kill_all_watchers are real and safe when dirs empty.
# ============================================================

# _neon_watcher_root — absolute metroplex path from NEON_ROOT or ROOT
_neon_watcher_root() {
    if [[ -n "${NEON_ROOT:-}" ]]; then
        printf '%s\n' "$NEON_ROOT"
        return 0
    fi
    if [[ -n "${ROOT:-}" ]]; then
        printf '%s\n' "$ROOT"
        return 0
    fi
    printf '%s\n' ""
}

# spawn_watcher JOB_ID — start watcher if not .down and not running
# PR3 stub: always no-op (no real watcher binaries yet).
spawn_watcher() {
    local job_id="${1:-}"
    if [[ -z "$job_id" ]]; then
        return 0
    fi
    # Future: check .down, pidfile, launch .bin/nr_watcher_<id>
    return 0
}

# kill_watcher JOB_ID — TERM then KILL via pidfile; does not write .down
# Removes pidfile after kill attempt. Safe if missing pidfile/root.
kill_watcher() {
    local job_id="${1:-}"
    local root pf pid
    if [[ -z "$job_id" ]]; then
        return 0
    fi
    root=$(_neon_watcher_root)
    if [[ -z "$root" ]]; then
        return 0
    fi
    pf="$root/.watchers/${job_id}.pid"
    if [[ ! -f "$pf" ]]; then
        return 0
    fi
    pid=$(tr -d ' \n\r' < "$pf" 2>/dev/null || true)
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
        # Brief grace for TERM handlers (fractional sleep ok on macOS/Linux)
        sleep 0.2 2>/dev/null || true
        kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$pf" 2>/dev/null || true
    return 0
}

# kill_all_watchers — all pidfiles under .watchers/ + pkill -x known nr_watcher_* from .bin
# Safe no-op when NEON_ROOT/ROOT unset, or .watchers/ / .bin missing or empty.
kill_all_watchers() {
    local root wdir bindir pf job_id base
    root=$(_neon_watcher_root)
    if [[ -z "$root" ]]; then
        return 0
    fi

    wdir="$root/.watchers"
    if [[ -d "$wdir" ]]; then
        # Globs stay literal when empty; -f guard skips non-matches
        for pf in "$wdir"/*.pid; do
            if [[ ! -f "$pf" ]]; then
                continue
            fi
            job_id=$(basename -- "$pf" .pid)
            kill_watcher "$job_id"
        done
    fi

    bindir="$root/.bin"
    if [[ -d "$bindir" ]]; then
        for base in "$bindir"/nr_watcher_*; do
            # Skip if glob did not match (literal path remains)
            if [[ ! -e "$base" && ! -L "$base" ]]; then
                continue
            fi
            base=$(basename -- "$base")
            # Only exact process names known from .bin (never broad pkill)
            pkill -x "$base" 2>/dev/null || true
        done
    fi
    return 0
}
