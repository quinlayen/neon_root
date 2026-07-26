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

# Source repo-side job runtime + watchers if available (for accept/complete/board)
_neon_source_runtime() {
    local root repo
    root=$(_neon_root)
    [[ -n "$root" ]] || return 1
    export NEON_ROOT="$root"
    export ROOT="$root"
    # repo is parent of metroplex
    repo=$(cd "$root/.." && pwd)
    if [[ -f "$repo/scripts/lib/job_runtime.sh" ]]; then
        # shellcheck disable=SC1091
        source "$repo/scripts/lib/job_runtime.sh"
    fi
    if [[ -f "$repo/scripts/lib/watchers.sh" ]]; then
        # shellcheck disable=SC1091
        source "$repo/scripts/lib/watchers.sh"
    fi
    if [[ -f "$root/.tools" ]]; then
        # shellcheck disable=SC1091
        source "$root/.tools"
    fi
    return 0
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
        echo "  Try: look, ls -a, jobs, or cd to an exit listed by look."
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

# ── Inventory ────────────────────────────────────────────────

# _neon_basename_ok NAME — reject empty, ., .., path seps, -, and dotfiles
_neon_basename_ok() {
    local name="$1"
    if [[ -z "$name" || "$name" = "." || "$name" = ".." ]]; then
        return 1
    fi
    case "$name" in
        */*|*'\\'*|'-'|.*)
            return 1
            ;;
    esac
    return 0
}

inventory() {
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    echo ""
    echo "  ╔════════════════════════════════╗"
    echo "  ║       YOUR INVENTORY           ║"
    echo "  ╠════════════════════════════════╣"
    local items
    items=$(ls -A "$root/.inventory" 2>/dev/null)
    if [[ -z "$items" ]]; then
        echo "  ║  (empty)                       ║"
    else
        while IFS= read -r item; do
            printf "  ║  %-30s║\n" "$item"
        done <<< "$items"
    fi
    echo "  ╚════════════════════════════════╝"
    echo ""
}

take() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo "  Take what? Usage: take <filename>"
        return 1
    fi
    if ! _neon_basename_ok "$name"; then
        echo "  Refused: take only allows a simple basename in this room."
        echo "  (no paths, no '..', no '-', no dotfiles)"
        return 1
    fi
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    if [[ ! -f "./$name" ]]; then
        echo "  There is no '$name' here to take."
        return 1
    fi
    if [[ ! -f "./$name" || -L "./$name" ]]; then
        # Still allow regular files only (not dirs); -f is true for some symlinks to files
        :
    fi
    if [[ -d "./$name" ]]; then
        echo "  Can't take a directory."
        return 1
    fi
    mkdir -p "$root/.inventory"
    mv "./$name" "$root/.inventory/"
    echo "  Taken: $name"
}

drop() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        echo "  Drop what? Usage: drop <filename>"
        return 1
    fi
    if ! _neon_basename_ok "$name"; then
        echo "  Refused: drop only allows a simple basename."
        echo "  (no paths, no '..', no '-', no dotfiles)"
        return 1
    fi
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    if [[ ! -f "$root/.inventory/$name" ]]; then
        echo "  You don't have '$name' in your inventory."
        return 1
    fi
    if [[ -e "./$name" ]]; then
        echo "  Something named '$name' already exists here."
        return 1
    fi
    mv "$root/.inventory/$name" .
    echo "  Dropped: $name"
}

# ── Job board helpers ────────────────────────────────────────

jobs() {
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    _neon_source_runtime || true
    board_sync_from_ledger "$root" 2>/dev/null || true

    local b id title skill reason line
    echo ""
    echo "  JOB BOARD — Metroplex Fixer Net"
    echo "  ────────────────────────────────────────────"
    for b in OPEN ACTIVE LOCKED COMPLETED; do
        local bucket
        bucket=$(printf '%s' "$b" | tr '[:upper:]' '[:lower:]')
        echo "  $b"
        local any=0
        for id in "$root/safehouse/job_board/$bucket"/*; do
            [[ -f "$id" ]] || continue
            any=1
            title=$(_meta_get "$id" "TITLE" 2>/dev/null || basename -- "$id")
            skill=$(_meta_get "$id" "SKILL" 2>/dev/null || echo "?")
            reason=$(_meta_get "$id" "REASON" 2>/dev/null || echo "")
            if [[ "$bucket" = "locked" && -n "$reason" ]]; then
                printf "    %-16s %-28s [%s]  need: %s\n" "$(basename -- "$id")" "$title" "$skill" "${reason#missing }"
            else
                printf "    %-16s %-28s [%s]\n" "$(basename -- "$id")" "$title" "$skill"
            fi
        done
        if [[ "$any" -eq 0 ]]; then
            echo "    (none)"
        fi
    done
    echo "  ────────────────────────────────────────────"
    local py git sql
    py="${HAS_PYTHON3:-0}"; git="${HAS_GIT:-0}"; sql="${HAS_SQLITE3:-0}"
    if [[ -f "$root/.tools" ]]; then
        # shellcheck disable=SC1091
        source "$root/.tools"
        py="${HAS_PYTHON3:-0}"; git="${HAS_GIT:-0}"; sql="${HAS_SQLITE3:-0}"
    fi
    printf "  Tools: python3:%s  git:%s  sqlite3:%s\n" \
        "$( [[ "$py" = "1" ]] && echo yes || echo no )" \
        "$( [[ "$git" = "1" ]] && echo yes || echo no )" \
        "$( [[ "$sql" = "1" ]] && echo yes || echo no )"
    echo ""
}

brief() {
    local job_id="${1:-}"
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    if [[ -z "$job_id" ]]; then
        # If cwd under jobs/<id>
        local rel="${PWD#"$root"/}"
        case "$rel" in
            jobs/*)
                job_id="${rel#jobs/}"
                job_id="${job_id%%/*}"
                ;;
        esac
    fi
    if [[ -z "$job_id" ]]; then
        echo "  Usage: brief <job_id>"
        return 1
    fi
    if [[ -f "$root/jobs/$job_id/.objective" ]]; then
        echo ""
        cat "$root/jobs/$job_id/.objective"
        echo ""
    else
        echo "  No brief for '$job_id'."
        return 1
    fi
}

accept() {
    local job_id="${1:-}"
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    if [[ -z "$job_id" ]]; then
        echo "  Usage: accept <job_id>"
        return 1
    fi
    _neon_source_runtime || true
    board_sync_from_ledger "$root" 2>/dev/null || true

    # Unknown job?
    if [[ ! -d "$root/jobs/$job_id" && ! -f "$root/jobs/$job_id/.job_meta" ]]; then
        # Still might be only on board — check shipped
        if [[ -z "$(board_find "$root" "$job_id")" ]]; then
            echo "  No such job: $job_id"
            return 1
        fi
    fi

    local state bucket
    state=$(ledger_state "$root" "$job_id")
    bucket=$(board_bucket "$root" "$job_id")

    if [[ "$state" = "completed" ]]; then
        echo "  Contract already closed."
        return 1
    fi
    if [[ "$bucket" = "locked" ]]; then
        local reason path
        path=$(board_find "$root" "$job_id")
        reason=$(_meta_get "$path" "REASON" 2>/dev/null || echo "missing tool")
        echo "  Locked: $reason"
        echo "  Install the tool, then re-run ./play.sh (tools re-detect each launch)."
        return 1
    fi
    if [[ "$state" = "accepted" ]]; then
        load_job_meta "$root" "$job_id"
        echo "  Already on the clock: $job_id"
        echo "  Work path: $root/${META_WORK:-jobs/$job_id}"
        return 0
    fi
    if [[ "$bucket" != "open" && "$bucket" != "none" && "$state" != "none" ]]; then
        # open or no board yet with content
        :
    fi
    if [[ "$bucket" != "open" ]]; then
        # If content exists and tools OK, allow; else error
        load_job_meta "$root" "$job_id"
        if ! tools_satisfy "${META_REQUIRES:-}"; then
            echo "  Locked or unavailable: $job_id"
            return 1
        fi
    fi

    # Soft tutorial nudge
    local tut
    tut=$(ledger_state "$root" "tutorial_grid")
    if [[ "$job_id" != "tutorial_grid" && "$tut" != "completed" ]]; then
        echo "  Note: Tutorial (tutorial_grid) still open — recommended first jack-in."
        echo "  Accepting anyway (soft gate)."
    fi

    ledger_set "$root" "$job_id" "accepted"
    load_job_meta "$root" "$job_id"
    # Capture before board_sync (which reloads META_* for every job)
    local acc_title="$META_TITLE"
    local acc_work="$META_WORK"
    local acc_skill="$META_SKILL"
    local acc_spine="$META_SPINE"
    local acc_req="$META_REQUIRES"
    local acc_watch="${META_HAS_WATCHER:-0}"
    board_remove_all "$root" "$job_id"
    write_board_file "$root" "active" "$job_id" \
        "$acc_title" "$acc_skill" "$acc_spine" \
        "$acc_req" "$acc_work" ""
    board_sync_from_ledger "$root" 2>/dev/null || true

    if [[ "$acc_watch" = "1" ]]; then
        spawn_watcher "$job_id" 2>/dev/null || true
    fi

    echo "  Contract accepted: $acc_title"
    echo "  Work path: $root/$acc_work"
    echo "  try:  cd $root/$acc_work"
    echo "        look | brief | complete"
}

complete() {
    local job_id="${1:-}"
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    _neon_source_runtime || true
    board_sync_from_ledger "$root" 2>/dev/null || true

    if [[ -z "$job_id" ]]; then
        local rel="${PWD#"$root"/}"
        case "$rel" in
            jobs/*)
                job_id="${rel#jobs/}"
                job_id="${job_id%%/*}"
                ;;
        esac
    fi
    if [[ -z "$job_id" ]]; then
        # Exactly one accepted?
        local count=0 cand=""
        local id st
        for id in $(shipped_job_ids "$root"); do
            st=$(ledger_state "$root" "$id")
            if [[ "$st" = "accepted" ]]; then
                count=$((count + 1))
                cand="$id"
            fi
        done
        if [[ "$count" -eq 1 ]]; then
            job_id="$cand"
        else
            echo "  Usage: complete <job_id>"
            echo "  (or cd into jobs/<id> first)"
            return 1
        fi
    fi

    local state
    state=$(ledger_state "$root" "$job_id")
    if [[ "$state" = "completed" ]]; then
        echo "  Already paid out."
        return 0
    fi
    if [[ "$state" != "accepted" ]]; then
        echo "  Accept the contract before cashing out."
        return 1
    fi

    local work="$root/jobs/$job_id"
    if [[ ! -d "$work" ]]; then
        echo "  Job workspace missing: $job_id"
        return 1
    fi
    if [[ ! -f "$work/.check_complete" ]]; then
        echo "  Job misconfigured; report bug"
        return 1
    fi

    local out rc
    export NEON_ROOT="$root"
    export JOB_ID="$job_id"
    export NEON_SEED_FILE="$root/.seed"
    out=$(cd "$work" && bash .check_complete 2>/dev/null)
    rc=$?

    if [[ "$rc" -eq 0 ]]; then
        ledger_set "$root" "$job_id" "completed"
        load_job_meta "$root" "$job_id"
        local done_title="$META_TITLE"
        local done_work="$META_WORK"
        local done_skill="$META_SKILL"
        local done_spine="$META_SPINE"
        local done_req="$META_REQUIRES"
        board_remove_all "$root" "$job_id"
        write_board_file "$root" "completed" "$job_id" \
            "$done_title" "$done_skill" "$done_spine" \
            "$done_req" "$done_work" ""
        board_sync_from_ledger "$root" 2>/dev/null || true
        echo "  Contract complete: $done_title"
        echo "  Payout: creds hit your account. Nice work, runner."
        return 0
    elif [[ "$rc" -eq 2 ]]; then
        echo "  Job misconfigured; report bug"
        return 1
    else
        # first line of stdout is hint
        local first
        first=$(printf '%s\n' "$out" | head -n 1)
        if [[ -n "$first" ]]; then
            echo "  $first"
        else
            echo "  Not complete yet. Try hint or re-read the room (-)."
        fi
        return 1
    fi
}

status() {
    local root
    root=$(_neon_root)
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    _neon_source_runtime || true
    board_sync_from_ledger "$root" 2>/dev/null || true

    local id skill stretch state req
    local done=0 total=0
    local shell_d=0 shell_t=0 py_d=0 py_t=0 git_d=0 git_t=0 sql_d=0 sql_t=0

    if [[ -f "$root/.tools" ]]; then
        # shellcheck disable=SC1091
        source "$root/.tools"
    fi

    for id in $(shipped_job_ids "$root"); do
        load_job_meta "$root" "$id"
        skill="${META_SKILL:-shell}"
        stretch="${META_STRETCH:-0}"
        req="${META_REQUIRES:-}"
        state=$(ledger_state "$root" "$id")

        # Stretch: track separately; not in victory denominator unless we want bonus only
        if [[ "$stretch" = "1" ]]; then
            if [[ "$state" = "completed" ]]; then
                case "$skill" in
                    sql) sql_d=$((sql_d + 1)) ;;
                esac
            fi
            if tools_satisfy "$req"; then
                case "$skill" in
                    sql) sql_t=$((sql_t + 1)) ;;
                esac
            fi
            continue
        fi

        # Non-stretch: only tool-eligible count for victory
        if ! tools_satisfy "$req"; then
            continue
        fi
        total=$((total + 1))
        case "$skill" in
            shell) shell_t=$((shell_t + 1)) ;;
            python) py_t=$((py_t + 1)) ;;
            git) git_t=$((git_t + 1)) ;;
            sql) sql_t=$((sql_t + 1)) ;;
        esac
        if [[ "$state" = "completed" ]]; then
            done=$((done + 1))
            case "$skill" in
                shell) shell_d=$((shell_d + 1)) ;;
                python) py_d=$((py_d + 1)) ;;
                git) git_d=$((git_d + 1)) ;;
                sql) sql_d=$((sql_d + 1)) ;;
            esac
        fi
    done

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║         METROPLEX STATUS             ║"
    echo "  ╠══════════════════════════════════════╣"
    printf "  ║  %-36s║\n" "Progress: ${done} / ${total} contracts"
    printf "  ║  %-36s║\n" "shell:  ${shell_d}/${shell_t}"
    printf "  ║  %-36s║\n" "python: ${py_d}/${py_t}"
    printf "  ║  %-36s║\n" "git:    ${git_d}/${git_t}"
    printf "  ║  %-36s║\n" "sql:    ${sql_d}/${sql_t} (stretch)"
    local py="${HAS_PYTHON3:-0}" g="${HAS_GIT:-0}" s="${HAS_SQLITE3:-0}"
    printf "  ║  %-36s║\n" "Tools: py=$([[ "$py" = 1 ]] && echo y || echo n) git=$([[ "$g" = 1 ]] && echo y || echo n) sql=$([[ "$s" = 1 ]] && echo y || echo n)"

    if [[ -f "$root/.session_unlocks" ]]; then
        local su
        su=$(tr -d ' \n\r' < "$root/.session_unlocks")
        if [[ -n "$su" && "$su" != "0" ]]; then
            echo "  ╠══════════════════════════════════════╣"
            echo "  ║  Note: New contracts available after ║"
            echo "  ║  tool install (or game update).      ║"
            echo "  ║  CLEARED needs newly unlocked jobs.  ║"
        fi
    fi

    if [[ "$total" -gt 0 && "$done" -eq "$total" ]]; then
        echo "  ╠══════════════════════════════════════╣"
        echo "  ║         *** CLEARED ***              ║"
        echo "  ║     Metroplex contracts done         ║"
    else
        echo "  ╠══════════════════════════════════════╣"
        echo "  ║         IN PROGRESS                  ║"
    fi
    echo "  ╚══════════════════════════════════════╝"
    echo ""
}
