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

# _neon_watcher_job_id_ok JOB_ID — 1 if JOB_ID matches ^[a-z0-9_]+$ (DESIGN)
# Rejects empty, path separators, uppercase, and other unsafe path chars.
_neon_watcher_job_id_ok() {
    case "$1" in
        ''|*[!a-z0-9_]*) return 1 ;;
    esac
    return 0
}

# spawn_watcher JOB_ID — start watcher if not .down and not running
# PR3 stub: always no-op (no real watcher binaries yet).
spawn_watcher() {
    local job_id="${1:-}"
    if ! _neon_watcher_job_id_ok "$job_id"; then
        return 0
    fi
    # Future: check .down, pidfile, launch .bin/nr_watcher_<id>
    return 0
}

# kill_watcher JOB_ID — TERM then KILL via pidfile; does not write .down
# Removes pidfile after kill attempt. Safe if missing pidfile/root.
# Only signals positive decimal integer PIDs (never -1, 0, or process groups).
kill_watcher() {
    local job_id="${1:-}"
    local root pf pid
    if ! _neon_watcher_job_id_ok "$job_id"; then
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
    # Accept only positive decimal integers (no signs, no leading zeros, no zero).
    # Rejects -1 (all processes), 0 (process group), negatives (process groups).
    case "$pid" in
        ''|*[!0-9]*|0|0*)
            rm -f "$pf" 2>/dev/null || true
            return 0
            ;;
    esac
    # End-of-options form so a future pid never becomes a kill flag
    kill -TERM -- "$pid" 2>/dev/null || true
    # Skip grace/KILL if process already exited after TERM
    if ! kill -0 -- "$pid" 2>/dev/null; then
        rm -f "$pf" 2>/dev/null || true
        return 0
    fi
    # Brief grace for TERM handlers (fractional sleep ok on macOS/Linux)
    sleep 0.2 2>/dev/null || true
    kill -KILL -- "$pid" 2>/dev/null || true
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
            # Invalid basenames are never signaled; still remove the stray pidfile
            if ! _neon_watcher_job_id_ok "$job_id"; then
                rm -f "$pf" 2>/dev/null || true
                continue
            fi
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
