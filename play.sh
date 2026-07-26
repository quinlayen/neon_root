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
        echo "Unknown option: $1  (try ./play.sh --help)"
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
    exit 0
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
    echo "  Game world is missing. Try: ./play.sh --new"
    exit 1
fi

# ── Resolve start room (last save, else safehouse) ───────────
START_ROOM="safehouse"
if [[ -f "$WORLD/.save_state" ]]; then
    # shellcheck disable=SC1091
    source "$WORLD/.save_state"
    if [[ -n "${SAVE_ROOM:-}" && -d "$WORLD/$SAVE_ROOM" ]]; then
        START_ROOM="$SAVE_ROOM"
    fi
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
echo "  try:  look   |  hint   |  whereami   |  save"
echo "        ls -a  |  cd <exit>"
echo "  exit: type  exit  (progress is kept on disk)"
echo "  ────────────────────────────────────────────────"
echo ""
look
EOF

echo ""
echo "  Starting game shell… (type 'exit' to leave)"
echo ""
exec bash --rcfile "$RCFILE" -i
