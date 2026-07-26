#!/bin/bash
# ============================================================
#  Neon Root — job ledger, board, tools gate, ensure/sync
#  Sourceable. bash 3.2 safe (no associative arrays).
# ============================================================

# tools_satisfy REQUIRES_STRING — space-separated tool names (python3 git sqlite3)
# Uses ROOT/.tools or HAS_* already in environment.
tools_satisfy() {
    local reqs="${1:-}"
    local root="${NEON_ROOT:-${ROOT:-}}"
    local t has_py=0 has_git=0 has_sql=0

    if [[ -n "$root" && -f "$root/.tools" ]]; then
        # shellcheck disable=SC1090
        source "$root/.tools" 2>/dev/null || true
    fi
    has_py="${HAS_PYTHON3:-0}"
    has_git="${HAS_GIT:-0}"
    has_sql="${HAS_SQLITE3:-0}"

    # Empty requires always OK
    if [[ -z "$(printf '%s' "$reqs" | tr -d ' \t\n\r')" ]]; then
        return 0
    fi

    for t in $reqs; do
        case "$t" in
            python3)
                [[ "$has_py" = "1" ]] || return 1
                ;;
            git)
                [[ "$has_git" = "1" ]] || return 1
                ;;
            sqlite3)
                [[ "$has_sql" = "1" ]] || return 1
                ;;
            "")
                ;;
            *)
                # Unknown tool name: treat as unsatisfied
                return 1
                ;;
        esac
    done
    return 0
}

# ledger_state ROOT JOB_ID — prints completed|accepted|none
ledger_state() {
    local root="$1"
    local job_id="$2"
    local line state
    if [[ -z "$root" || -z "$job_id" || ! -f "$root/.job_ledger" ]]; then
        printf 'none\n'
        return 0
    fi
    # Last matching row wins
    state="none"
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            \#*|'') continue ;;
        esac
        if [[ "${line%%|*}" = "$job_id" ]]; then
            state=$(printf '%s' "$line" | awk -F'|' '{print $2}')
        fi
    done < "$root/.job_ledger"
    case "$state" in
        accepted|completed) printf '%s\n' "$state" ;;
        *) printf 'none\n' ;;
    esac
}

# ledger_set ROOT JOB_ID STATE — accepted or completed; preserves accepted_at
ledger_set() {
    local root="$1"
    local job_id="$2"
    local new_state="$3"
    local ledger tmp line id st acc comp now found=0
    local accepted_at="" completed_at=""

    ledger="$root/.job_ledger"
    tmp="$root/.job_ledger.tmp.$$"
    now=$(date -u +%Y-%m-%dT%H:%M:%S)

    if [[ ! -f "$ledger" ]]; then
        printf '# id|state|accepted_at|completed_at\n' > "$ledger"
    fi

    # Read existing row if any
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            \#*|'') continue ;;
        esac
        id="${line%%|*}"
        if [[ "$id" = "$job_id" ]]; then
            st=$(printf '%s' "$line" | awk -F'|' '{print $2}')
            accepted_at=$(printf '%s' "$line" | awk -F'|' '{print $3}')
            completed_at=$(printf '%s' "$line" | awk -F'|' '{print $4}')
            found=1
        fi
    done < "$ledger"

    if [[ "$new_state" = "accepted" ]]; then
        [[ -n "$accepted_at" ]] || accepted_at="$now"
        completed_at=""
    elif [[ "$new_state" = "completed" ]]; then
        [[ -n "$accepted_at" ]] || accepted_at="$now"
        completed_at="$now"
    else
        return 1
    fi

    # Rewrite ledger without this job, then append
    {
        printf '# id|state|accepted_at|completed_at\n'
        while IFS= read -r line || [[ -n "$line" ]]; do
            case "$line" in
                \#*|'') continue ;;
            esac
            id="${line%%|*}"
            if [[ "$id" != "$job_id" && -n "$id" ]]; then
                printf '%s\n' "$line"
            fi
        done < "$ledger"
        printf '%s|%s|%s|%s\n' "$job_id" "$new_state" "$accepted_at" "$completed_at"
    } > "$tmp"
    mv "$tmp" "$ledger"
}

# board_find ROOT JOB_ID — prints path if board file exists, else empty
board_find() {
    local root="$1"
    local job_id="$2"
    local b
    for b in open active completed locked; do
        if [[ -f "$root/safehouse/job_board/$b/$job_id" ]]; then
            printf '%s\n' "$root/safehouse/job_board/$b/$job_id"
            return 0
        fi
    done
    printf '%s\n' ""
}

# board_bucket ROOT JOB_ID — prints open|active|completed|locked|none
board_bucket() {
    local root="$1"
    local job_id="$2"
    local b
    for b in open active completed locked; do
        if [[ -f "$root/safehouse/job_board/$b/$job_id" ]]; then
            printf '%s\n' "$b"
            return 0
        fi
    done
    printf 'none\n'
}

# board_remove_all ROOT JOB_ID
board_remove_all() {
    local root="$1"
    local job_id="$2"
    local b
    for b in open active completed locked; do
        rm -f "$root/safehouse/job_board/$b/$job_id" 2>/dev/null || true
    done
}

# write_board_file ROOT BUCKET JOB_ID TITLE SKILL SPINE REQUIRES WORK REASON
write_board_file() {
    local root="$1"
    local bucket="$2"
    local job_id="$3"
    local title="$4"
    local skill="$5"
    local spine="$6"
    local requires="$7"
    local work="$8"
    local reason="$9"
    local dir="$root/safehouse/job_board/$bucket"
    mkdir -p "$dir"
    cat > "$dir/$job_id" <<EOF
TITLE=$title
SKILL=$skill
SPINE=$spine
REQUIRES=$requires
WORK=$work
REASON=$reason
EOF
}

# _meta_get FILE KEY — parse KEY=value from .job_meta or board file
_meta_get() {
    local file="$1"
    local key="$2"
    local line
    [[ -f "$file" ]] || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            "$key"=*)
                printf '%s\n' "${line#*=}"
                return 0
                ;;
        esac
    done < "$file"
    return 1
}

# load_job_meta ROOT JOB_ID — sets META_TITLE META_SKILL META_SPINE META_REQUIRES META_WORK META_STRETCH META_HAS_WATCHER
load_job_meta() {
    local root="$1"
    local job_id="$2"
    local meta="$root/jobs/$job_id/.job_meta"
    local board path

    META_TITLE="$job_id"
    META_SKILL="shell"
    META_SPINE="netrunner"
    META_REQUIRES=""
    META_WORK="jobs/$job_id"
    META_STRETCH="0"
    META_HAS_WATCHER="0"

    if [[ -f "$meta" ]]; then
        META_TITLE=$(_meta_get "$meta" "JOB_TITLE" 2>/dev/null || _meta_get "$meta" "TITLE" || echo "$job_id")
        META_SKILL=$(_meta_get "$meta" "JOB_SKILL" 2>/dev/null || _meta_get "$meta" "SKILL" || echo "shell")
        META_SPINE=$(_meta_get "$meta" "JOB_SPINE" 2>/dev/null || _meta_get "$meta" "SPINE" || echo "netrunner")
        META_REQUIRES=$(_meta_get "$meta" "JOB_REQUIRES" 2>/dev/null || _meta_get "$meta" "REQUIRES" || echo "")
        META_WORK=$(_meta_get "$meta" "WORK_ROOT" 2>/dev/null || _meta_get "$meta" "WORK" || echo "jobs/$job_id")
        META_STRETCH=$(_meta_get "$meta" "JOB_STRETCH" 2>/dev/null || echo "0")
        META_HAS_WATCHER=$(_meta_get "$meta" "JOB_HAS_WATCHER" 2>/dev/null || echo "0")
    fi

    # Salvage from existing board if present
    path=$(board_find "$root" "$job_id")
    if [[ -n "$path" ]]; then
        local t
        t=$(_meta_get "$path" "TITLE" 2>/dev/null || true)
        [[ -n "$t" ]] && META_TITLE="$t"
        t=$(_meta_get "$path" "SKILL" 2>/dev/null || true)
        [[ -n "$t" ]] && META_SKILL="$t"
        t=$(_meta_get "$path" "SPINE" 2>/dev/null || true)
        [[ -n "$t" ]] && META_SPINE="$t"
        t=$(_meta_get "$path" "REQUIRES" 2>/dev/null || true)
        [[ -n "$t" ]] && META_REQUIRES="$t"
        t=$(_meta_get "$path" "WORK" 2>/dev/null || true)
        [[ -n "$t" ]] && META_WORK="$t"
    fi
}

# shipped_job_ids ROOT — print job ids that have .job_meta under jobs/
shipped_job_ids() {
    local root="$1"
    local d meta id
    if [[ ! -d "$root/jobs" ]]; then
        return 0
    fi
    for d in "$root/jobs"/*/; do
        [[ -d "$d" ]] || continue
        meta="${d}.job_meta"
        if [[ -f "$meta" ]]; then
            id=$(_meta_get "$meta" "JOB_ID" 2>/dev/null || basename -- "$d")
            # basename of dir if empty
            if [[ -z "$id" ]]; then
                id=$(basename -- "$d")
            fi
            printf '%s\n' "$id"
        fi
    done
}

# board_sync_from_ledger ROOT
board_sync_from_ledger() {
    local root="$1"
    local id state reason
    local shipped_list

    [[ -n "$root" && -d "$root" ]] || return 1
    mkdir -p "$root/safehouse/job_board/open" \
             "$root/safehouse/job_board/active" \
             "$root/safehouse/job_board/completed" \
             "$root/safehouse/job_board/locked"

    shipped_list=$(shipped_job_ids "$root")

    # Sync each shipped job
    while IFS= read -r id || [[ -n "$id" ]]; do
        [[ -n "$id" ]] || continue
        load_job_meta "$root" "$id"
        state=$(ledger_state "$root" "$id")
        board_remove_all "$root" "$id"
        reason=""
        if [[ "$state" = "completed" ]]; then
            write_board_file "$root" "completed" "$id" \
                "$META_TITLE" "$META_SKILL" "$META_SPINE" \
                "$META_REQUIRES" "$META_WORK" ""
        elif [[ "$state" = "accepted" ]]; then
            write_board_file "$root" "active" "$id" \
                "$META_TITLE" "$META_SKILL" "$META_SPINE" \
                "$META_REQUIRES" "$META_WORK" ""
        elif tools_satisfy "$META_REQUIRES"; then
            write_board_file "$root" "open" "$id" \
                "$META_TITLE" "$META_SKILL" "$META_SPINE" \
                "$META_REQUIRES" "$META_WORK" ""
        else
            reason="missing"
            # Prefer first missing tool name
            local t
            for t in $META_REQUIRES; do
                if ! tools_satisfy "$t"; then
                    reason="missing $t"
                    break
                fi
            done
            write_board_file "$root" "locked" "$id" \
                "$META_TITLE" "$META_SKILL" "$META_SPINE" \
                "$META_REQUIRES" "$META_WORK" "$reason"
        fi
    done <<EOF
$shipped_list
EOF

    # Delete orphan board files not in shipped set
    local b f base known
    for b in open active completed locked; do
        for f in "$root/safehouse/job_board/$b"/*; do
            [[ -f "$f" ]] || continue
            base=$(basename -- "$f")
            known=0
            while IFS= read -r id || [[ -n "$id" ]]; do
                [[ "$id" = "$base" ]] && known=1 && break
            done <<EOF
$shipped_list
EOF
            if [[ "$known" -eq 0 ]]; then
                rm -f "$f"
            fi
        done
    done
}

# ensure_jobs_for_tools ROOT — install missing content, create board, unlock
# Requires: REPO, seed_token available, seed already loaded, job plugins at REPO/jobs/*.job.sh
ensure_jobs_for_tools() {
    local root="$1"
    local repo="${REPO:-}"
    local plugin session_unlocks=0
    local job_file

    [[ -n "$root" && -d "$root" ]] || return 1
    if [[ -z "$repo" ]]; then
        # Derive from common helper if possible
        if [[ -n "${_NEON_COMMON_DIR:-}" ]]; then
            repo=$(cd "$_NEON_COMMON_DIR/../.." && pwd)
        fi
    fi
    [[ -n "$repo" && -d "$repo/jobs" ]] || return 0

    # shellcheck disable=SC1091
    [[ -f "$repo/scripts/lib/seed.sh" ]] && source "$repo/scripts/lib/seed.sh"
    # shellcheck disable=SC1091
    [[ -f "$repo/scripts/lib/watchers.sh" ]] && source "$repo/scripts/lib/watchers.sh"

    export NEON_ROOT="$root"
    export ROOT="$root"

    if [[ -f "$root/.seed" ]]; then
        seed_load "$root" 2>/dev/null || true
    fi

    # shellcheck disable=SC2045
    for job_file in $(ls "$repo/jobs"/*.job.sh 2>/dev/null | sort); do
        [[ -f "$job_file" ]] || continue
        unset JOB_ID JOB_TITLE JOB_SKILL JOB_SPINE JOB_REQUIRES JOB_DISTRICT
        unset JOB_TIER JOB_STRETCH JOB_HAS_WATCHER
        unset -f job_install 2>/dev/null || true
        # shellcheck disable=SC1090
        source "$job_file"

        case "${JOB_ID:-}" in
            ''|*[!a-z0-9_]*)
                warn "ensure: invalid JOB_ID in $job_file — skip"
                continue
                ;;
        esac
        if ! declare -f job_install >/dev/null 2>&1; then
            warn "ensure: no job_install in $job_file — skip"
            continue
        fi

        # 1) Content (install missing; rebuild git placeholders when git appears)
        if [[ ! -d "$root/jobs/$JOB_ID" ]]; then
            job_install "$root"
            debug "ENSURE_INSTALL $JOB_ID"
            printf 'ENSURE_INSTALL %s\n' "$JOB_ID" >> "$root/.generate.log" 2>/dev/null || true
        elif [[ -f "$root/jobs/$JOB_ID/.git_install_pending" ]] && command -v git >/dev/null 2>&1; then
            job_install "$root"
            debug "ENSURE_REBUILD $JOB_ID"
            printf 'ENSURE_REBUILD %s\n' "$JOB_ID" >> "$root/.generate.log" 2>/dev/null || true
        fi

        # Normalize REQUIRES to space string
        local req_str=""
        if [[ "$(declare -p JOB_REQUIRES 2>/dev/null)" == "declare -a"* ]]; then
            # bash array
            local i
            for i in "${JOB_REQUIRES[@]+"${JOB_REQUIRES[@]}"}"; do
                req_str="$req_str $i"
            done
            req_str=$(printf '%s' "$req_str" | sed 's/^ *//')
        else
            req_str="${JOB_REQUIRES:-}"
        fi

        local board_path state
        board_path=$(board_find "$root" "$JOB_ID")
        state=$(ledger_state "$root" "$JOB_ID")

        # 2) Board file existence
        if [[ -z "$board_path" ]]; then
            if [[ "$state" = "completed" ]]; then
                write_board_file "$root" "completed" "$JOB_ID" \
                    "${JOB_TITLE:-$JOB_ID}" "${JOB_SKILL:-shell}" "${JOB_SPINE:-netrunner}" \
                    "$req_str" "jobs/$JOB_ID" ""
            elif [[ "$state" = "accepted" ]]; then
                write_board_file "$root" "active" "$JOB_ID" \
                    "${JOB_TITLE:-$JOB_ID}" "${JOB_SKILL:-shell}" "${JOB_SPINE:-netrunner}" \
                    "$req_str" "jobs/$JOB_ID" ""
            elif tools_satisfy "$req_str"; then
                write_board_file "$root" "open" "$JOB_ID" \
                    "${JOB_TITLE:-$JOB_ID}" "${JOB_SKILL:-shell}" "${JOB_SPINE:-netrunner}" \
                    "$req_str" "jobs/$JOB_ID" ""
                session_unlocks=$((session_unlocks + 1))
            else
                local reason="missing"
                local t
                for t in $req_str; do
                    if ! tools_satisfy "$t"; then
                        reason="missing $t"
                        break
                    fi
                done
                write_board_file "$root" "locked" "$JOB_ID" \
                    "${JOB_TITLE:-$JOB_ID}" "${JOB_SKILL:-shell}" "${JOB_SPINE:-netrunner}" \
                    "$req_str" "jobs/$JOB_ID" "$reason"
                session_unlocks=$((session_unlocks + 1))
            fi
            printf 'ENSURE_BOARD %s\n' "$JOB_ID" >> "$root/.generate.log" 2>/dev/null || true
            continue
        fi

        # 3) Unlock locked → open when tools appear
        local bucket
        bucket=$(board_bucket "$root" "$JOB_ID")
        if [[ "$bucket" = "locked" ]] && tools_satisfy "$req_str" \
            && [[ "$state" != "completed" && "$state" != "accepted" ]]; then
            load_job_meta "$root" "$JOB_ID"
            board_remove_all "$root" "$JOB_ID"
            write_board_file "$root" "open" "$JOB_ID" \
                "$META_TITLE" "$META_SKILL" "$META_SPINE" \
                "$META_REQUIRES" "$META_WORK" ""
            session_unlocks=$((session_unlocks + 1))
            printf 'ENSURE_UNLOCK %s\n' "$JOB_ID" >> "$root/.generate.log" 2>/dev/null || true
        fi
    done

    printf '%s\n' "$session_unlocks" > "$root/.session_unlocks"
    board_sync_from_ledger "$root"
}

# install_all_jobs ROOT — --new path: source each plugin, job_install, board place
install_all_jobs() {
    local root="$1"
    local repo="${REPO:-}"
    local job_file

    [[ -n "$repo" && -d "$repo/jobs" ]] || return 0

    # shellcheck disable=SC2045
    for job_file in $(ls "$repo/jobs"/*.job.sh 2>/dev/null | sort); do
        [[ -f "$job_file" ]] || continue
        unset JOB_ID JOB_TITLE JOB_SKILL JOB_SPINE JOB_REQUIRES JOB_DISTRICT
        unset JOB_TIER JOB_STRETCH JOB_HAS_WATCHER
        unset -f job_install 2>/dev/null || true
        # shellcheck disable=SC1090
        source "$job_file"

        case "${JOB_ID:-}" in
            ''|*[!a-z0-9_]*)
                die "invalid JOB_ID in $job_file"
                ;;
        esac
        if ! declare -f job_install >/dev/null 2>&1; then
            die "job_install missing in $job_file"
        fi

        job_install "$root"

        local req_str=""
        if [[ "$(declare -p JOB_REQUIRES 2>/dev/null)" == "declare -a"* ]]; then
            local i
            for i in "${JOB_REQUIRES[@]+"${JOB_REQUIRES[@]}"}"; do
                req_str="$req_str $i"
            done
            req_str=$(printf '%s' "$req_str" | sed 's/^ *//')
        else
            req_str="${JOB_REQUIRES:-}"
        fi

        if tools_satisfy "$req_str"; then
            write_board_file "$root" "open" "$JOB_ID" \
                "${JOB_TITLE:-$JOB_ID}" "${JOB_SKILL:-shell}" "${JOB_SPINE:-netrunner}" \
                "$req_str" "jobs/$JOB_ID" ""
            printf 'INSTALLED %s %s open\n' "$JOB_ID" "${JOB_SKILL:-shell}" >> "$root/.generate.log"
        else
            local reason="missing"
            local t
            for t in $req_str; do
                if ! tools_satisfy "$t"; then
                    reason="missing $t"
                    break
                fi
            done
            write_board_file "$root" "locked" "$JOB_ID" \
                "${JOB_TITLE:-$JOB_ID}" "${JOB_SKILL:-shell}" "${JOB_SPINE:-netrunner}" \
                "$req_str" "jobs/$JOB_ID" "$reason"
            printf 'INSTALLED %s %s locked reason=%s\n' "$JOB_ID" "${JOB_SKILL:-shell}" "$reason" >> "$root/.generate.log"
        fi
    done
}

# respawn_watchers_for_accepted ROOT
respawn_watchers_for_accepted() {
    local root="$1"
    local id state meta
    export NEON_ROOT="$root"
    for id in $(shipped_job_ids "$root"); do
        state=$(ledger_state "$root" "$id")
        [[ "$state" = "accepted" ]] || continue
        load_job_meta "$root" "$id"
        if [[ "${META_HAS_WATCHER:-0}" = "1" ]]; then
            spawn_watcher "$id"
        fi
    done
}
