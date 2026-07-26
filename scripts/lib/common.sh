#!/bin/bash
# ============================================================
#  Neon Root — shared helpers (generator and scripts)
#  Sourceable. bash 3.2 safe (no associative arrays).
#
#  Prefer sourcing via an absolute path. repo_root_from defaults
#  use the absolute directory of this file captured at source time
#  so later cd does not break resolution.
# ============================================================

# Absolute dir of this file at source time (survives later cd)
_NEON_COMMON_DIR=$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || _NEON_COMMON_DIR=""

# die MSG... — print error to stderr and exit 1
die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

# log MSG... — plain message to stdout
log() {
    printf '%s\n' "$*"
}

# info MSG... — informational line to stderr
info() {
    printf '  %s\n' "$*" >&2
}

# warn MSG... — warning to stderr
warn() {
    printf 'warn: %s\n' "$*" >&2
}

# debug MSG... — only when NEON_ROOT_DEBUG=1
debug() {
    if [[ "${NEON_ROOT_DEBUG:-0}" = "1" ]]; then
        printf 'debug: %s\n' "$*" >&2
    fi
    return 0
}

# abs_path PATH — print absolute path (file or dir).
# Existing dirs resolve via cd/pwd; missing paths join cwd + path.
abs_path() {
    local p="$1"
    local dir base
    if [[ -z "$p" ]]; then
        printf '%s\n' "$(pwd)"
        return 0
    fi
    if [[ -d "$p" ]]; then
        (cd "$p" && pwd)
        return $?
    fi
    dir=$(dirname -- "$p")
    base=$(basename -- "$p")
    if [[ -d "$dir" ]]; then
        printf '%s/%s\n' "$(cd "$dir" && pwd)" "$base"
        return 0
    fi
    # Fallback: prefix cwd for relative paths
    case "$p" in
        /*) printf '%s\n' "$p" ;;
        *)  printf '%s/%s\n' "$(pwd)" "$p" ;;
    esac
}

# abs_dir PATH — require existing directory; print absolute path or die
abs_dir() {
    local p="$1"
    if [[ ! -d "$p" ]]; then
        die "not a directory: $p"
    fi
    (cd "$p" && pwd) || die "cannot resolve directory: $p"
}

# repo_root_from [SCRIPT_PATH] — absolute repo root given a script under scripts/
# Default: absolute dir of common.sh captured at source (_NEON_COMMON_DIR).
# Callers may pass an absolute SCRIPT_PATH; relative paths need cwd still valid.
repo_root_from() {
    local script="${1:-}"
    local dir
    if [[ -n "$script" ]]; then
        dir=$(cd "$(dirname -- "$script")" && pwd) || die "cannot resolve script dir: $script"
    elif [[ -n "${_NEON_COMMON_DIR:-}" ]]; then
        dir="$_NEON_COMMON_DIR"
    else
        script="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
        dir=$(cd "$(dirname -- "$script")" && pwd) || die "cannot resolve script dir"
    fi
    # scripts/ or scripts/lib/ → go up to repo root
    case "$dir" in
        */scripts/lib) printf '%s\n' "$(cd "$dir/../.." && pwd)" ;;
        */scripts)     printf '%s\n' "$(cd "$dir/.." && pwd)" ;;
        *)             printf '%s\n' "$dir" ;;
    esac
}
