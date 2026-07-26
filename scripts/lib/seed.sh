#!/bin/bash
# ============================================================
#  Neon Root — seed file and portable seed_token
#  Sourceable. bash 3.2 safe.
#
#  On --new: seed_write_new ROOT writes 32 hex chars to ROOT/.seed
#  (no trailing newline). Always strip on read with tr -d ' \n\r'.
# ============================================================

# Internal: loaded seed string (also exported as NEON_SEED / SEED)
NEON_SEED="${NEON_SEED:-}"
SEED="${SEED:-$NEON_SEED}"

# seed_write_new ROOT — write 32 hex chars (16 urandom bytes) to ROOT/.seed
seed_write_new() {
    local root="$1"
    local seed_file hex
    if [[ -z "$root" ]]; then
        printf 'seed_write_new: ROOT required\n' >&2
        return 1
    fi
    if [[ ! -d "$root" ]]; then
        printf 'seed_write_new: not a directory: %s\n' "$root" >&2
        return 1
    fi
    seed_file="$root/.seed"
    # 16 bytes → 32 hex chars; strip spaces/newlines from od
    hex=$(od -An -N 16 -tx1 /dev/urandom | tr -d ' \n\r')
    if [[ ${#hex} -lt 32 ]]; then
        printf 'seed_write_new: failed to read /dev/urandom\n' >&2
        return 1
    fi
    # Exact 32 hex chars, no trailing newline
    printf '%s' "${hex:0:32}" > "$seed_file" || return 1
    NEON_SEED="${hex:0:32}"
    SEED="$NEON_SEED"
    return 0
}

# seed_load ROOT — load NEON_SEED/SEED from ROOT/.seed (whitespace stripped)
# Seed is opaque; non-32/non-hex still accepted with a warn (hand-edited .seed).
seed_load() {
    local root="$1"
    local seed_file raw
    if [[ -z "$root" ]]; then
        printf 'seed_load: ROOT required\n' >&2
        return 1
    fi
    seed_file="$root/.seed"
    if [[ ! -f "$seed_file" ]]; then
        printf 'seed_load: missing %s\n' "$seed_file" >&2
        return 1
    fi
    raw=$(tr -d ' \n\r' < "$seed_file")
    if [[ -z "$raw" ]]; then
        printf 'seed_load: empty seed in %s\n' "$seed_file" >&2
        return 1
    fi
    if [[ ${#raw} -ne 32 ]]; then
        printf 'seed_load: warn: expected 32 hex chars, got %d\n' "${#raw}" >&2
    fi
    case "$raw" in
        *[!0-9a-fA-F]*)
            printf 'seed_load: warn: seed is not pure hex\n' >&2
            ;;
    esac
    NEON_SEED="$raw"
    SEED="$raw"
    return 0
}

# seed_token JOB_ID NAME [LEN]
# Portable SHA-256 hex of "seed:job_id:name"; first LEN chars (default 8).
# Uses shasum -a 256 with sha256sum fallback. LEN must be 1..64.
seed_token() {
    local job_id="$1"
    local name="$2"
    local len="${3:-8}"
    local seed hash

    if [[ -z "$job_id" || -z "$name" ]]; then
        printf 'seed_token: job_id and name required\n' >&2
        return 1
    fi

    # Positive integer 1..64 (sha256 hex is 64 chars). bash 3.2-safe (no =~).
    case "$len" in
        ''|*[!0-9]*)
            printf 'seed_token: len must be a positive integer (got %s)\n' "$len" >&2
            return 1
            ;;
    esac
    if [[ "$len" -lt 1 || "$len" -gt 64 ]]; then
        printf 'seed_token: len must be 1..64 (got %s)\n' "$len" >&2
        return 1
    fi

    seed="${NEON_SEED:-${SEED:-}}"
    if [[ -z "$seed" ]]; then
        printf 'seed_token: seed not loaded (call seed_load or seed_write_new first)\n' >&2
        return 1
    fi

    # Portable hash: shasum (macOS) or sha256sum (Linux); first field only
    hash=$(printf '%s' "${seed}:${job_id}:${name}" | (shasum -a 256 2>/dev/null || sha256sum))
    hash=${hash%% *}
    hash=${hash%%$'\t'*}
    if [[ -z "$hash" ]]; then
        printf 'seed_token: hash failed (need shasum or sha256sum)\n' >&2
        return 1
    fi

    printf '%s\n' "${hash:0:len}"
}
