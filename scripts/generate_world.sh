#!/bin/bash
# ============================================================
#  Neon Root — world generator (hub + districts + stubs)
#  Usage:
#    ./scripts/generate_world.sh --new
#    ./scripts/generate_world.sh --continue
#
#  Resolves REPO from this script's location; ROOT = REPO/metroplex.
#  bash 3.2 safe (no associative arrays, no mapfile).
# ============================================================

set -e

# --- Resolve absolute REPO and ROOT ------------------------------------------
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
source "$REPO/scripts/detect_tools.sh"

# Export for watchers.sh (NEON_ROOT preferred; ROOT also accepted)
export NEON_ROOT="$ROOT"
export ROOT

# --- CLI ---------------------------------------------------------------------
MODE=""
case "${1:-}" in
    --new|-n)
        MODE="new"
        ;;
    --continue|-c)
        MODE="continue"
        ;;
    --help|-h)
        cat <<'HELP'
Neon Root — world generator

  ./scripts/generate_world.sh --new       Wipe metroplex/ and rebuild hub
  ./scripts/generate_world.sh --continue  Refresh helpers / tools on existing world
  ./scripts/generate_world.sh --help      Show this help
HELP
        exit 0
        ;;
    "")
        die "usage: $0 --new | --continue  (try --help)"
        ;;
    *)
        die "unknown option: $1  (try --help)"
        ;;
esac

# --- Helpers -----------------------------------------------------------------

# write_game_functions — copy template to ROOT/.game_functions.sh (always overwrite)
write_game_functions() {
    local tpl="$REPO/scripts/templates/game_functions.sh"
    if [[ ! -f "$tpl" ]]; then
        die "missing helper template: $tpl"
    fi
    cp "$tpl" "$ROOT/.game_functions.sh" || die "cannot write $ROOT/.game_functions.sh"
}

# ensure_jobs_for_tools — PR3 stub (no job plugins yet)
ensure_jobs_for_tools() {
    return 0
}

# _write_room FILE content via stdin (heredoc)
# Room description is a regular file named "-"
_write_room() {
    local path="$1"
    cat > "$path"
}

# create_hub_mesh — districts, safehouse, symlinks, empty jobs/watchers/bin
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

    # ── Safehouse room ──────────────────────────────────────────
    _write_room "$ROOT/safehouse/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    SAFEHOUSE — Street Netrunner hub
  ═══════════════════════════════════════════════════

  Rain ticks against blackout glass. A battered jack-in cradle
  hums under a string of cheap neon. Your fixer's board glows
  in the corner — contracts, when they post, land there.

  This is home base. Districts radiate out as linked grid edges.
  The loadout rack is empty for now. The job board is quiet.

  Type: look   |   hint   |   cd <exit>
  ═══════════════════════════════════════════════════
ROOM

    _write_room "$ROOT/safehouse/.hint" <<'HINT'
  Hint: use look to scan the room, then cd into an exit
  (job_board, loadout, or a district). whereami and save
  work once helpers are sourced.
HINT

    _write_room "$ROOT/safehouse/job_board/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    JOB BOARD
  ═══════════════════════════════════════════════════

  A wall of flickering slots: open, active, completed, locked.
  No contracts are posted yet — the fixer is offline.

  Subdirs hold board files when gigs go live.
  ═══════════════════════════════════════════════════
ROOM

    _write_room "$ROOT/safehouse/loadout/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    LOADOUT
  ═══════════════════════════════════════════════════

  An empty rack and a grounded mat. Gear you take will land
  in inventory; nothing is stashed here yet.
  ═══════════════════════════════════════════════════
ROOM

    # Safehouse → district / jobs symlinks (relative)
    ln -sfn ../districts/dockside        "$ROOT/safehouse/dockside"
    ln -sfn ../districts/neon_market     "$ROOT/safehouse/neon_market"
    ln -sfn ../districts/helix_perimeter "$ROOT/safehouse/helix_perimeter"
    ln -sfn ../districts/archive_stack   "$ROOT/safehouse/archive_stack"
    ln -sfn ../districts/undergrid       "$ROOT/safehouse/undergrid"
    ln -sfn ../districts/corp_shard      "$ROOT/safehouse/corp_shard"
    ln -sfn ../jobs                      "$ROOT/safehouse/jobs"

    # ── District lore rooms ─────────────────────────────────────
    _write_room "$ROOT/districts/dockside/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    DOCKSIDE
  ═══════════════════════════════════════════════════

  Salt, rust, and pirate Wi-Fi. Container stacks form alleys;
  badge readers blink on warehouse doors. Good place to skim
  access tokens when jobs land.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/dockside/.hint" <<'HINT'
  Hint: cd safehouse to jack back to the hub, or follow
  helix_perimeter along the waterline firewall.
HINT

    _write_room "$ROOT/districts/helix_perimeter/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    HELIX PERIMETER
  ═══════════════════════════════════════════════════

  Glass towers and drone traffic. Helix Dynamics owns the
  skyline; the perimeter fence is more policy than steel.
  Watcher processes like it here.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/helix_perimeter/.hint" <<'HINT'
  Hint: dockside and corp_shard link from here. Safehouse
  is always one symlink away.
HINT

    _write_room "$ROOT/districts/neon_market/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    NEON MARKET
  ═══════════════════════════════════════════════════

  Vendor stalls under holographic awnings. Firmware, IDs,
  and bad coffee. Noise is cover; cameras still listen.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/neon_market/.hint" <<'HINT'
  Hint: archive_stack is a relative hop from the market edge.
HINT

    _write_room "$ROOT/districts/archive_stack/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    ARCHIVE STACK
  ═══════════════════════════════════════════════════

  Cold racks of seized repos and redacted dumps. The
  Collective leaves dead drops in the lower rows when
  the grid is quiet.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/archive_stack/.hint" <<'HINT'
  Hint: edges run to neon_market, undergrid, and corp_shard.
HINT

    _write_room "$ROOT/districts/undergrid/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    UNDERGRID
  ═══════════════════════════════════════════════════

  Maintenance tunnels under the city OS. Cable trays,
  forgotten jump boxes, and processes that never got a
  proper kill signal.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/undergrid/.hint" <<'HINT'
  Hint: climb back via archive_stack, or safehouse from any district.
HINT

    _write_room "$ROOT/districts/corp_shard/-" <<'ROOM'
  ═══════════════════════════════════════════════════
    CORP SHARD
  ═══════════════════════════════════════════════════

  A leased data shard humming behind badge-gated glass.
  Payroll tables and HR ghosts live here — when the SQL
  tool is online and a contract posts.
  ═══════════════════════════════════════════════════
ROOM
    _write_room "$ROOT/districts/corp_shard/.hint" <<'HINT'
  Hint: linked from helix_perimeter and archive_stack.
HINT

    # District → safehouse
    for d in $districts; do
        ln -sfn ../../safehouse "$ROOT/districts/$d/safehouse"
    done

    # District-to-district map edges (bidirectional relative symlinks)
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

# write_ledger_stub — empty/header-only authoritative ledger
write_ledger_stub() {
    cat > "$ROOT/.job_ledger" <<'LEDGER'
# Neon Root job ledger (authoritative)
# Rows: job_id status  (accepted|completed)
# Empty until jobs are accepted.
LEDGER
}

# --- Modes -------------------------------------------------------------------

if [[ "$MODE" == "new" ]]; then
    info "Neon Root — generating new world…"
    # Safe even when metroplex missing or .watchers empty
    kill_all_watchers
    rm -rf "$ROOT"
    mkdir -p "$ROOT"

    create_hub_mesh
    seed_write_new "$ROOT" || die "seed_write_new failed"
    detect_tools "$ROOT" >/dev/null || true
    seed_load "$ROOT" || die "seed_load failed"
    write_ledger_stub
    # empty inventory already created
    write_game_functions

    # Truncate/overwrite generate log on full --new
    {
        printf 'MODE=new\n'
        printf 'SEED_LEN=%s\n' "${#NEON_SEED}"
        printf 'ROOT=%s\n' "$ROOT"
        printf 'NOTE=no jobs installed (PR3 hub only)\n'
    } > "$ROOT/.generate.log"

    log ""
    log "  World ready: $ROOT"
    log "  Start room:  safehouse/"
    log "  Seed:        written (.seed)"
    log "  Helpers:     .game_functions.sh"
    log "  (No jobs yet — hub browse via: source metroplex/.game_functions.sh)"
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

info "Neon Root — continue (refresh helpers / tools)…"
detect_tools "$ROOT" >/dev/null || true
seed_load "$ROOT" || die "seed_load failed"
write_game_functions
# ensure_jobs_for_tools not required yet (no jobs)
ensure_jobs_for_tools "$ROOT" || true
# respawn_watchers not required with no accepted jobs

{
    printf 'MODE=continue\n'
    printf 'SEED_LEN=%s\n' "${#NEON_SEED}"
    printf 'ROOT=%s\n' "$ROOT"
    printf 'NOTE=helpers refreshed; no jobs yet\n'
} >> "$ROOT/.generate.log"

log ""
log "  Continue OK: helpers refreshed at $ROOT/.game_functions.sh"
log "  Seed: immutable (loaded)"
log ""
exit 0
