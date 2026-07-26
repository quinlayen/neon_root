# jobs/01_badge_skim.job.sh — hidden file + grep
JOB_ID="badge_skim"
JOB_TITLE="Lift the Dock Badge"
JOB_SKILL="shell"
JOB_SPINE="netrunner"
JOB_REQUIRES=()
JOB_DISTRICT="dockside"
JOB_TIER=1
JOB_STRETCH=0
JOB_HAS_WATCHER=0

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir/logs"
  local needle
  needle="$(seed_token "$JOB_ID" "badge" 8)"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    DOCK BADGE SKIM
  ═══════════════════════════════════════════════════
  A badge reader dumps access noise into logs/.
  Find the line with BADGE_ID= and recover the code.
  Write it to recovered_badge.txt (single line), then complete.
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: ls -a logs/ ; grep -R BADGE_ID logs/
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Grep the dock logs for BADGE_ID= and write the value to recovered_badge.txt.
EOF

  cat > "$jobdir/.job_meta" <<EOF
JOB_ID=$JOB_ID
JOB_TITLE=$JOB_TITLE
JOB_SKILL=$JOB_SKILL
JOB_SPINE=$JOB_SPINE
WORK_ROOT=jobs/$JOB_ID
JOB_REQUIRES=
JOB_STRETCH=0
JOB_HAS_WATCHER=0
EOF

  # Noise logs + hidden needle
  cat > "$jobdir/logs/noise_a.log" <<EOF
ts=1 status=ok
ts=2 status=retry
EOF
  cat > "$jobdir/logs/.reader_cache" <<EOF
# cache
BADGE_ID=${needle}
EOF
  cat > "$jobdir/logs/noise_b.log" <<EOF
ts=3 status=noise
EOF

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${needle}"
if [[ ! -f recovered_badge.txt ]]; then
  echo "Write the BADGE_ID value into recovered_badge.txt"
  exit 1
fi
got=\$(tr -d ' \\n\\r' < recovered_badge.txt)
if [[ "\$got" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "recovered_badge.txt does not match. grep -R BADGE_ID logs/"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
