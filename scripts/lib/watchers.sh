#!/bin/bash
# ============================================================
#  Neon Root — multi-watcher process helpers
#  Sourceable. bash 3.2 safe.
#
#  Paths (under metroplex root = NEON_ROOT or ROOT):
#    .bin/nr_watcher_<job_id>     executable
#    .watchers/<job_id>.pid       pidfile
#    .watchers/<job_id>.down      slain / down flag
# ============================================================

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

_neon_watcher_job_id_ok() {
    case "$1" in
        ''|*[!a-z0-9_]*) return 1 ;;
    esac
    return 0
}

_neon_watcher_running() {
    local root="$1"
    local job_id="$2"
    local pf pid
    pf="$root/.watchers/${job_id}.pid"
    [[ -f "$pf" ]] || return 1
    pid=$(tr -d ' \n\r' < "$pf" 2>/dev/null || true)
    case "$pid" in
        ''|*[!0-9]*|0|0*) return 1 ;;
    esac
    kill -0 -- "$pid" 2>/dev/null
}

# spawn_watcher JOB_ID — start watcher if binary exists, not .down, not running
spawn_watcher() {
    local job_id="${1:-}"
    local root bin pf down
    if ! _neon_watcher_job_id_ok "$job_id"; then
        return 0
    fi
    root=$(_neon_watcher_root)
    [[ -n "$root" ]] || return 0
    down="$root/.watchers/${job_id}.down"
    if [[ -f "$down" ]]; then
        return 0
    fi
    if _neon_watcher_running "$root" "$job_id"; then
        return 0
    fi
    bin="$root/.bin/nr_watcher_${job_id}"
    if [[ ! -x "$bin" ]]; then
        return 0
    fi
    mkdir -p "$root/.watchers"
    pf="$root/.watchers/${job_id}.pid"
    # Clean stale pidfile
    rm -f "$pf" 2>/dev/null || true
    NEON_WATCHER_DOWN="$down" NEON_WATCHER_PIDFILE="$pf" \
        "$bin" </dev/null >/dev/null 2>&1 &
    return 0
}

# kill_watcher JOB_ID — TERM then KILL via pidfile; does not write .down
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
    case "$pid" in
        ''|*[!0-9]*|0|0*)
            rm -f "$pf" 2>/dev/null || true
            return 0
            ;;
    esac
    kill -TERM -- "$pid" 2>/dev/null || true
    if ! kill -0 -- "$pid" 2>/dev/null; then
        rm -f "$pf" 2>/dev/null || true
        return 0
    fi
    sleep 0.2 2>/dev/null || true
    kill -KILL -- "$pid" 2>/dev/null || true
    rm -f "$pf" 2>/dev/null || true
    return 0
}

kill_all_watchers() {
    local root wdir bindir pf job_id base
    root=$(_neon_watcher_root)
    if [[ -z "$root" ]]; then
        return 0
    fi

    wdir="$root/.watchers"
    if [[ -d "$wdir" ]]; then
        for pf in "$wdir"/*.pid; do
            if [[ ! -f "$pf" ]]; then
                continue
            fi
            job_id=$(basename -- "$pf" .pid)
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
            if [[ ! -e "$base" && ! -L "$base" ]]; then
                continue
            fi
            base=$(basename -- "$base")
            pkill -x "$base" 2>/dev/null || true
        done
    fi
    return 0
}

# install_watcher_binary ROOT JOB_ID — write standard watcher script to .bin
install_watcher_binary() {
    local root="$1"
    local job_id="$2"
    local bin
    if ! _neon_watcher_job_id_ok "$job_id"; then
        return 1
    fi
    mkdir -p "$root/.bin" "$root/.watchers"
    bin="$root/.bin/nr_watcher_${job_id}"
    cat > "$bin" <<'WATCH_EOF'
#!/bin/bash
# Neon Root watcher process (basename must stay nr_watcher_*)
DOWN="${NEON_WATCHER_DOWN:-}"
PIDFILE="${NEON_WATCHER_PIDFILE:-}"
cleanup() {
    [[ -n "$DOWN" ]] && touch "$DOWN" 2>/dev/null || true
    [[ -n "$PIDFILE" ]] && rm -f "$PIDFILE" 2>/dev/null || true
    exit 0
}
trap cleanup TERM INT
trap '' HUP
if [[ -n "$PIDFILE" ]]; then
    echo $$ > "$PIDFILE"
fi
while true; do
    sleep 3600 &
    wait $! 2>/dev/null || true
done
WATCH_EOF
    chmod +x "$bin"
}
