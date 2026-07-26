# jobs/04_kill_watcher.job.sh — process kill
JOB_ID="kill_watcher"
JOB_TITLE="Silence the Watcher"
JOB_SKILL="shell"
JOB_SPINE="netrunner"
JOB_REQUIRES=()
JOB_DISTRICT="helix_perimeter"
JOB_TIER=1
JOB_STRETCH=0
JOB_HAS_WATCHER=1

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir"

  # Install watcher binary (does not start process)
  install_watcher_binary "$root" "$JOB_ID"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    SILENCE THE WATCHER
  ═══════════════════════════════════════════════════
  A hostile process is named:  nr_watcher_kill_watcher
  Accept this job to spawn it (if not already down).
  Find its PID with ps, then kill it (TERM is enough).
  When the process dies it leaves a .down flag.
  Then run: complete
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: ps aux | grep nr_watcher_kill_watcher
        kill <pid>
  Do NOT kill -9 -1 or broad pkill patterns.
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Kill process nr_watcher_kill_watcher so the .down flag appears, then complete.
EOF

  cat > "$jobdir/.job_meta" <<EOF
JOB_ID=$JOB_ID
JOB_TITLE=$JOB_TITLE
JOB_SKILL=$JOB_SKILL
JOB_SPINE=$JOB_SPINE
WORK_ROOT=jobs/$JOB_ID
JOB_REQUIRES=
JOB_STRETCH=0
JOB_HAS_WATCHER=1
EOF

  cat > "$jobdir/.check_complete" <<'EOF'
#!/bin/bash
ROOT="${NEON_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  echo "NEON_ROOT missing; misconfigured"
  exit 2
fi
if [[ -f "$ROOT/.watchers/kill_watcher.down" ]]; then
  exit 0
fi
# Also accept if process is gone and no pidfile (player killed hard)
if [[ -f "$ROOT/.watchers/kill_watcher.pid" ]]; then
  pid=$(tr -d ' \n\r' < "$ROOT/.watchers/kill_watcher.pid" 2>/dev/null || true)
  if [[ -n "$pid" ]] && kill -0 -- "$pid" 2>/dev/null; then
    echo "Watcher still running. ps aux | grep nr_watcher_kill_watcher then kill <pid>"
    exit 1
  fi
fi
# process dead but no .down — touch not required if process gone after accept
if ! pgrep -x nr_watcher_kill_watcher >/dev/null 2>&1; then
  # ensure .down for pedagogy consistency
  mkdir -p "$ROOT/.watchers"
  touch "$ROOT/.watchers/kill_watcher.down" 2>/dev/null || true
  exit 0
fi
echo "Watcher still running. kill the nr_watcher_kill_watcher process"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
