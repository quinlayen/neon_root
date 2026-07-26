#!/bin/bash
# ============================================================
#  Neon Root — world generator (hub + jobs)
#  Usage:
#    ./scripts/generate_world.sh --new
#    ./scripts/generate_world.sh --continue
#  bash 3.2 safe.
# ============================================================

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR=$(cd "$(dirname -- "$SCRIPT_PATH")" && pwd) || exit 1
REPO=$(cd "$SCRIPT_DIR/.." && pwd) || exit 1
ROOT="$REPO/metroplex"

cd "$REPO" || exit 1

# shellcheck disable=SC1091
source "$REPO/scripts/lib/common.sh"
# shellcheck disable=SC1091
source "$REPO/scripts/lib/seed.sh"
# shellcheck disable=SC1091
source "$REPO/scripts/lib/watchers.sh"
# shellcheck disable=SC1091
source "$REPO/scripts/lib/job_runtime.sh"
# shellcheck disable=SC1091
source "$REPO/scripts/detect_tools.sh"

export NEON_ROOT="$ROOT"
export ROOT
export REPO

MODE=""
case "${1:-}" in
    --new|-n) MODE="new" ;;
    --continue|-c) MODE="continue" ;;
    --help|-h)
        cat <<'HELP'
Neon Root — world generator

  ./scripts/generate_world.sh --new       Wipe metroplex/ and rebuild
  ./scripts/generate_world.sh --continue  Refresh helpers / tools / jobs
  ./scripts/generate_world.sh --help      Show this help
HELP
        exit 0
        ;;
    "") die "usage: $0 --new | --continue  (try --help)" ;;
    *) die "unknown option: $1  (try --help)" ;;
esac

write_game_functions() {
    local tpl="$REPO/scripts/templates/game_functions.sh"
    if [[ ! -f "$tpl" ]]; then
        die "missing helper template: $tpl"
    fi
    cp "$tpl" "$ROOT/.game_functions.sh" || die "cannot write $ROOT/.game_functions.sh"
}

_write_room() {
    local path="$1"
    cat > "$path"
}

create_hub_mesh() {
    local d
    local districts="dockside helix_perimeter neon_market archive_stack undergrid corp_shard"

    mkdir -p "$ROOT/.inventory"
    mkdir -p "$ROOT/.bin"
    mkdir -p "$ROOT/.watchers"
    mkdir -p "$ROOT/jobs"
    mkdir -p "$ROOT/safehouse/job_board/open"
    mkdir -p "$ROOT/safehouse/job_board/active"
    mkdir -p "$ROOT/safehouse/job_board/completed"
    mkdir -p "$ROOT/safehouse/job_board/locked"
    mkdir -p "$ROOT/safehouse/loadout"
    mkdir -p "$ROOT/districts"

    for d in $districts; do
        mkdir -p "$ROOT/districts/$d"
    done

    _write_room "$ROOT/safehouse/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    SAFEHOUSE — Street Netrunner hub
  ═══════════════════════════════════════════════════

  Rain ticks against blackout glass. A battered jack-in cradle
  hums under a string of cheap neon. Your fixer's board glows
  in the corner — contracts land there.

  This is home base. Districts radiate out as linked grid edges.

  Type: look | jobs | accept <id> | status | hint
  ═══════════════════════════════════════════════════
ROOM

    _write_room "$ROOT/safehouse/.hint" <<'HINT'
  Hint: run jobs to see the board, accept tutorial_grid first,
  then cd jobs/tutorial_grid and complete the uplink.
HINT

    _write_room "$ROOT/safehouse/job_board/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    JOB BOARD
  ═══════════════════════════════════════════════════

  Open / active / completed / locked slots.
  Type: jobs   (from any room with helpers loaded)
  ═══════════════════════════════════════════════════
ROOM

    _write_room "$ROOT/safehouse/loadout/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    LOADOUT
  ═══════════════════════════════════════════════════

  Drop gear here or use take/drop into inventory.
  ═══════════════════════════════════════════════════
ROOM

    ln -sfn ../districts/dockside        "$ROOT/safehouse/dockside"
    ln -sfn ../districts/neon_market     "$ROOT/safehouse/neon_market"
    ln -sfn ../districts/helix_perimeter "$ROOT/safehouse/helix_perimeter"
    ln -sfn ../districts/archive_stack   "$ROOT/safehouse/archive_stack"
    ln -sfn ../districts/undergrid       "$ROOT/safehouse/undergrid"
    ln -sfn ../districts/corp_shard      "$ROOT/safehouse/corp_shard"
    ln -sfn ../jobs                      "$ROOT/safehouse/jobs"

    _write_room "$ROOT/districts/dockside/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    DOCKSIDE
  ═══════════════════════════════════════════════════

  Salt, rust, and pirate Wi-Fi. Badge readers blink on
  warehouse doors. Good place to skim access tokens.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/dockside/.hint" <<'HINT'
  Hint: jobs badge_skim and archive_drop stage here.
HINT

    _write_room "$ROOT/districts/helix_perimeter/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    HELIX PERIMETER
  ═══════════════════════════════════════════════════

  Glass towers and drone traffic. Watcher processes like it here.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/helix_perimeter/.hint" <<'HINT'
  Hint: perm_gate and kill_watcher contracts.
HINT

    _write_room "$ROOT/districts/neon_market/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    NEON MARKET
  ═══════════════════════════════════════════════════

  Vendor stalls under holographic awnings. Noise is cover.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/neon_market/.hint" <<'HINT'
  Hint: log_spike and dash_payload live on this edge.
HINT

    _write_room "$ROOT/districts/archive_stack/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    ARCHIVE STACK
  ═══════════════════════════════════════════════════

  Cold racks of seized repos. Git safehouses burn here.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/archive_stack/.hint" <<'HINT'
  Hint: git_safehouse and git_stash_drop.
HINT

    _write_room "$ROOT/districts/undergrid/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    UNDERGRID
  ═══════════════════════════════════════════════════

  Maintenance tunnels. Implant compilers hum below.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/undergrid/.hint" <<'HINT'
  Hint: implant_parse (python) stages here.
HINT

    _write_room "$ROOT/districts/corp_shard/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    CORP SHARD
  ═══════════════════════════════════════════════════

  Payroll tables and HR ghosts — when sqlite3 is online.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/corp_shard/.hint" <<'HINT'
  Hint: payroll_shard stretch job (optional).
HINT

    for d in $districts; do
        ln -sfn ../../safehouse "$ROOT/districts/$d/safehouse"
    done

    ln -sfn ../helix_perimeter "$ROOT/districts/dockside/helix_perimeter"
    ln -sfn ../dockside        "$ROOT/districts/helix_perimeter/dockside"
    ln -sfn ../archive_stack   "$ROOT/districts/neon_market/archive_stack"
    ln -sfn ../neon_market     "$ROOT/districts/archive_stack/neon_market"
    ln -sfn ../archive_stack   "$ROOT/districts/undergrid/archive_stack"
    ln -sfn ../undergrid       "$ROOT/districts/archive_stack/undergrid"
    ln -sfn ../corp_shard      "$ROOT/districts/helix_perimeter/corp_shard"
    ln -sfn ../helix_perimeter "$ROOT/districts/corp_shard/helix_perimeter"
    ln -sfn ../corp_shard      "$ROOT/districts/archive_stack/corp_shard"
    ln -sfn ../archive_stack   "$ROOT/districts/corp_shard/archive_stack"
}

write_ledger_stub() {
    cat > "$ROOT/.job_ledger" <<'LEDGER'
# id|state|accepted_at|completed_at
LEDGER
}

if [[ "$MODE" == "new" ]]; then
    info "Neon Root — generating new world…"
    kill_all_watchers
    # chmod 000 puzzle dirs (perm_gate) block rm -rf without a mode reset first
    if [[ -d "$ROOT" ]]; then
        chmod -R u+rwx "$ROOT" 2>/dev/null || true
    fi
    rm -rf "$ROOT" || die "cannot remove $ROOT (close any shell cd'd into metroplex, then retry --new)"
    mkdir -p "$ROOT"

    create_hub_mesh
    seed_write_new "$ROOT" || die "seed_write_new failed"
    detect_tools "$ROOT" >/dev/null || warn "detect_tools failed; .tools may be missing"
    seed_load "$ROOT" || die "seed_load failed"
    write_ledger_stub

    {
        printf 'MODE=new\n'
        printf 'SEED_LEN=%s\n' "${#NEON_SEED}"
        printf 'ROOT=%s\n' "$ROOT"
    } > "$ROOT/.generate.log"

    install_all_jobs "$ROOT"
    board_sync_from_ledger "$ROOT"
    write_game_functions

    log ""
    log "  World ready: $ROOT"
    log "  Start room:  safehouse/"
    log "  Seed:        written (.seed)"
    log "  Helpers:     .game_functions.sh"
    log "  try:  ./play.sh"
    log ""
    exit 0
fi

# --continue
if [[ ! -d "$ROOT" ]]; then
    die "no metroplex world found at $ROOT — run: $0 --new"
fi
if [[ ! -f "$ROOT/.seed" ]]; then
    die "missing $ROOT/.seed — run: $0 --new"
fi

info "Neon Root — continue (refresh helpers / tools / jobs)…"
detect_tools "$ROOT" >/dev/null || warn "detect_tools failed; .tools may be missing"
seed_load "$ROOT" || die "seed_load failed"
write_game_functions
ensure_jobs_for_tools "$ROOT" || true
board_sync_from_ledger "$ROOT" || true
respawn_watchers_for_accepted "$ROOT" || true

{
    printf 'MODE=continue\n'
    printf 'SEED_LEN=%s\n' "${#NEON_SEED}"
    printf 'ROOT=%s\n' "$ROOT"
} >> "$ROOT/.generate.log"

log ""
log "  Continue OK: helpers refreshed at $ROOT/.game_functions.sh"
log "  Seed: immutable (loaded)"
log ""
exit 0
