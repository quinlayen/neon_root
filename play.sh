#!/bin/bash
# ============================================================
#  Neon Root — One-command launcher
# ============================================================
#  Usage (from this directory):
#
#    ./play.sh              # continue if possible, else new game
#    ./play.sh --new        # wipe and start fresh
#    ./play.sh --continue   # resume only (error if no world)
#    ./play.sh --tools      # detect tools, print, exit
#    ./play.sh --help
#
#  Starts an interactive shell with game helpers already loaded.
#  Type 'exit' to leave — progress stays on disk.
#  bash 3.2 safe (no associative arrays).
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

WORLD="$SCRIPT_DIR/metroplex"
GEN="$SCRIPT_DIR/scripts/generate_world.sh"
DETECT="$SCRIPT_DIR/scripts/detect_tools.sh"

# Single flag only (no stacked options)
if [[ "$#" -gt 1 ]]; then
    echo "Too many arguments: $*" >&2
    echo "  (try ./play.sh --help)" >&2
    exit 1
fi

MODE="auto"
case "${1:-}" in
    --new|-n)       MODE="new" ;;
    --continue|-c)  MODE="continue" ;;
    --tools|-t)     MODE="tools" ;;
    --help|-h)
        cat <<'HELP'
Neon Root — launcher

  ./play.sh              Continue existing game, or create one
  ./play.sh --new        Wipe progress and start a new game
  ./play.sh --continue   Resume only (fails if no world exists)
  ./play.sh --tools      Detect python3/git/sqlite3 and print; exit
  ./play.sh --help       Show this help

Exactly one flag (or none for auto). Extra arguments are rejected.

After launch you are in a game shell with helpers loaded.
Type look, hint, whereami, save — or real Linux commands.
Type exit when you are done (progress stays on disk).
HELP
        exit 0
        ;;
    "")
        MODE="auto"
        ;;
    *)
        echo "Unknown option: $1  (try ./play.sh --help)" >&2
        exit 1
        ;;
esac

# ── Tool detection (always; update .tools if world exists) ───
# --tools: print and exit without launching a shell.
if [[ ! -f "$DETECT" ]]; then
    echo "  Missing detect_tools: $DETECT" >&2
    exit 1
fi

if [[ "$MODE" == "tools" ]]; then
    if [[ -d "$WORLD" ]]; then
        bash "$DETECT" "$WORLD"
    else
        bash "$DETECT"
    fi
    exit $?
fi

# Re-detect before generate (writes .tools when metroplex/ exists)
if [[ -d "$WORLD" ]]; then
    bash "$DETECT" "$WORLD" >/dev/null || true
else
    bash "$DETECT" >/dev/null || true
fi

# ── Ensure the world exists ──────────────────────────────────
if [[ ! -x "$GEN" && ! -f "$GEN" ]]; then
    echo "  Missing generator: $GEN" >&2
    exit 1
fi

if [[ "$MODE" == "new" ]]; then
    bash "$GEN" --new || exit 1
elif [[ "$MODE" == "continue" ]]; then
    bash "$GEN" --continue || exit 1
else
    # auto: continue if a usable world exists, else new
    if [[ -d "$WORLD" && -f "$WORLD/.game_functions.sh" && -f "$WORLD/.seed" ]]; then
        bash "$GEN" --continue || exit 1
    else
        bash "$GEN" --new || exit 1
    fi
fi

if [[ ! -f "$WORLD/.game_functions.sh" ]]; then
    echo "  Game world is missing. Try: ./play.sh --new" >&2
    exit 1
fi

# ── Resolve start room (last save, else safehouse) ───────────
# Do NOT source .save_state (arbitrary shell). Parse SAVE_ROOM= only.
# Accept only relative paths that stay under metroplex/ as directories.
START_ROOM="safehouse"
if [[ -f "$WORLD/.save_state" ]]; then
    _save_line=""
    _save_raw=""
    _save_ok=0
    _world_abs=""
    _room_abs=""

    _save_line=$(grep '^SAVE_ROOM=' "$WORLD/.save_state" 2>/dev/null | head -n 1) || true
    if [[ -n "$_save_line" ]]; then
        _save_raw="${_save_line#SAVE_ROOM=}"
        # Strip one layer of matching single or double quotes (save() writes double-quoted)
        if [[ "$_save_raw" == \"*\" ]]; then
            _save_raw="${_save_raw#\"}"
            _save_raw="${_save_raw%\"}"
        elif [[ "$_save_raw" == \'*\' ]]; then
            _save_raw="${_save_raw#\'}"
            _save_raw="${_save_raw%\'}"
        fi

        # Reject empty, absolute, backslash, or any ".." path component
        if [[ -n "$_save_raw" && "$_save_raw" != /* && "$_save_raw" != *\\* ]]; then
            case "/${_save_raw}/" in
                */../*) ;;  # reject parent traversal
                *)
                    if [[ -d "$WORLD/$_save_raw" ]]; then
                        _world_abs=$(cd "$WORLD" && pwd) || _world_abs=""
                        _room_abs=$(cd "$WORLD/$_save_raw" && pwd) || _room_abs=""
                        if [[ -n "$_world_abs" && -n "$_room_abs" ]]; then
                            case "$_room_abs" in
                                "$_world_abs"|"$_world_abs"/*)
                                    _save_ok=1
                                    ;;
                            esac
                        fi
                    fi
                    ;;
            esac
        fi
    fi

    if [[ "$_save_ok" -eq 1 ]]; then
        START_ROOM="$_save_raw"
    fi
    unset _save_line _save_raw _save_ok _world_abs _room_abs
fi

START_PATH="$WORLD/$START_ROOM"

# Stable rcfile inside the world (must survive until the new bash reads it;
# do not use EXIT trap + mktemp + exec — the trap would delete it first).
RCFILE="$WORLD/.play_rc"
cat > "$RCFILE" <<EOF
# Neon Root game shell — written by play.sh
# shellcheck disable=SC1091
source "$WORLD/.game_functions.sh"
cd "$START_PATH" || cd "$WORLD/safehouse" || exit 1

export PS1='\[\e[1;36m\]neon\[\e[0m\]:\W\$ '

echo ""
echo "  ────────────────────────────────────────────────"
echo "  Neon Root — game shell ready. Helpers loaded."
echo "  Room: $START_ROOM"
echo ""
echo "  try:  look | jobs | accept <id> | complete | status"
echo "        hint | inventory | whereami | save"
echo "  exit: type  exit  (progress is kept on disk)"
echo "  ────────────────────────────────────────────────"
echo ""
look
EOF

echo ""
echo "  Starting game shell… (type 'exit' to leave)"
echo ""
exec bash --rcfile "$RCFILE" -i
