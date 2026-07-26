# Neon Root — Game Helper Functions
# Written to metroplex/.game_functions.sh on every --new / --continue.
# Do not edit the copy under metroplex/; edit this template instead.
# Source:  source metroplex/.game_functions.sh
# bash 3.2 safe (no associative arrays, no mapfile).

# Walk up from PWD looking for metroplex root (.inventory dir + .game_functions.sh)
_neon_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.inventory" && -f "$dir/.game_functions.sh" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir=$(dirname -- "$dir")
    done
    printf '%s\n' ""
}

# look — room description (- file), exits (*/), items (non-hidden regular files except -)
look() {
    if [[ -f "./-" ]]; then
        echo ""
        cat "./-"
    else
        echo ""
        echo "  You see nothing special about this place."
        echo "  (You may not be inside the game world.)"
    fi

    echo ""

    local has_exits=0
    local exit_list=""
    local d
    for d in */; do
        if [[ -d "$d" ]]; then
            has_exits=1
            exit_list="${exit_list}  ${d%/}"$'\n'
        fi
    done 2>/dev/null

    if [[ $has_exits -eq 1 ]]; then
        echo "  EXITS:"
        printf '%s' "$exit_list"
        echo ""
    else
        echo "  EXITS: none (dead end — use 'cd ..' to go back)"
        echo ""
    fi

    local has_items=0
    local item_list=""
    local f
    for f in *; do
        if [[ -f "$f" && "$f" != "-" ]]; then
            has_items=1
            item_list="${item_list}  $f"$'\n'
        fi
    done 2>/dev/null

    if [[ $has_items -eq 1 ]]; then
        echo "  ITEMS:"
        printf '%s' "$item_list"
    fi
}

# hint — cat .hint if present
hint() {
    if [[ -f ".hint" ]]; then
        echo ""
        cat ".hint"
        echo ""
    else
        echo ""
        echo "  No hints available here."
        echo "  Try: look, ls -a, or cd to an exit listed by look."
        echo ""
    fi
}

# whereami — relative path from metroplex root
whereami() {
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    local rel="${PWD#"$root"/}"
    if [[ "$rel" == "$PWD" ]]; then
        rel="(metroplex root)"
    fi
    echo ""
    echo "  You are in: $rel"
    echo "  Full path:  $PWD"
    echo ""
}

# save — write .save_state with SAVE_ROOM and SAVE_TIME
save() {
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi

    local rel="${PWD#"$root"/}"
    if [[ "$rel" == "$PWD" ]]; then
        rel=""
    fi

    cat > "$root/.save_state" <<SAVE_EOF
# Neon Root save bookmark — written by the 'save' command
# The real save data is the metroplex/ directory itself.
SAVE_ROOM="$rel"
SAVE_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
SAVE_EOF

    # Truncate so full line fits %-36s (reserve prefix + 3-char ellipsis):
    #   "Room: " (6)  + body ≤ 30  → if over: first 27 + "..."
    #   "Last room: " (11) + body ≤ 25 → if over: first 22 + "..."
    local room_disp="${rel:-.}"
    local last_disp="$rel"
    if [[ ${#room_disp} -gt 30 ]]; then
        room_disp="${room_disp:0:27}..."
    fi
    if [[ ${#last_disp} -gt 25 ]]; then
        last_disp="${last_disp:0:22}..."
    fi

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║              GAME SAVED              ║"
    echo "  ╠══════════════════════════════════════╣"
    printf "  ║  %-36s║\n" "Room: ${room_disp}"
    printf "  ║  %-36s║\n" "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  ╠══════════════════════════════════════╣"
    echo "  ║  World state is already on disk.     ║"
    echo "  ║  To resume later:                    ║"
    echo "  ║                                      ║"
    echo "  ║    ./play.sh                         ║"
    if [[ -n "$rel" ]]; then
        printf "  ║  %-36s║\n" "Last room: ${last_disp}"
    else
        echo "  ║    start room: safehouse             ║"
    fi
    echo "  ║    look                              ║"
    echo "  ╚══════════════════════════════════════╝"
    echo ""
}
