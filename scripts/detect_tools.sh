#!/bin/bash
# ============================================================
#  Neon Root — tool detection (python3, git, sqlite3)
#  Sourceable or executable. bash 3.2 safe.
#
#  Usage:
#    ./scripts/detect_tools.sh [ROOT]   # print; write ROOT/.tools if dir
#    source scripts/detect_tools.sh
#    detect_tools [ROOT]                # same as above
#
#  When ROOT is omitted, uses <repo>/metroplex if it exists.
#  Always prints results to stdout when executed; when sourced,
#  detect_tools prints and optionally writes .tools.
# ============================================================

# detect_tools [ROOT]
# Sets HAS_PYTHON3, HAS_GIT, HAS_SQLITE3 and *_BIN in the current shell
# when sourced. Writes ROOT/.tools when a world directory is available.
detect_tools() {
    local root="${1:-}"
    local script_dir repo
    local python3_bin git_bin sqlite3_bin
    local has_python3=0 has_git=0 has_sqlite3=0
    local out_file=""

    python3_bin=$(command -v python3 2>/dev/null || true)
    git_bin=$(command -v git 2>/dev/null || true)
    sqlite3_bin=$(command -v sqlite3 2>/dev/null || true)

    if [[ -n "$python3_bin" ]]; then
        has_python3=1
    fi
    if [[ -n "$git_bin" ]]; then
        has_git=1
    fi
    if [[ -n "$sqlite3_bin" ]]; then
        has_sqlite3=1
    fi

    # Export for callers that source this file
    HAS_PYTHON3=$has_python3
    HAS_GIT=$has_git
    HAS_SQLITE3=$has_sqlite3
    PYTHON3_BIN=$python3_bin
    GIT_BIN=$git_bin
    SQLITE3_BIN=$sqlite3_bin

    # Resolve default world root when not given
    if [[ -z "$root" ]]; then
        script_dir=$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) 2>/dev/null || script_dir=""
        if [[ -n "$script_dir" ]]; then
            repo=$(cd "$script_dir/.." && pwd) 2>/dev/null || repo=""
            if [[ -n "$repo" && -d "$repo/metroplex" ]]; then
                root="$repo/metroplex"
            fi
        fi
    fi

    if [[ -n "$root" && -d "$root" ]]; then
        out_file="$root/.tools"
        {
            printf 'HAS_PYTHON3=%s\n' "$has_python3"
            printf 'HAS_GIT=%s\n' "$has_git"
            printf 'HAS_SQLITE3=%s\n' "$has_sqlite3"
            printf 'PYTHON3_BIN=%s\n' "$python3_bin"
            printf 'GIT_BIN=%s\n' "$git_bin"
            printf 'SQLITE3_BIN=%s\n' "$sqlite3_bin"
        } > "$out_file"
    fi

    # Always print detection results (play.sh --tools / smoke)
    printf 'HAS_PYTHON3=%s\n' "$has_python3"
    printf 'HAS_GIT=%s\n' "$has_git"
    printf 'HAS_SQLITE3=%s\n' "$has_sqlite3"
    printf 'PYTHON3_BIN=%s\n' "$python3_bin"
    printf 'GIT_BIN=%s\n' "$git_bin"
    printf 'SQLITE3_BIN=%s\n' "$sqlite3_bin"

    return 0
}

# Run when executed as a script (not when sourced)
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
    detect_tools "$@"
fi
