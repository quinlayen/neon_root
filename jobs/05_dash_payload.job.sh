# jobs/05_dash_payload.job.sh — leading-dash filenames
JOB_ID="dash_payload"
JOB_TITLE="Defuse Dash-Named Payload"
JOB_SKILL="shell"
JOB_SPINE="netrunner"
JOB_REQUIRES=()
JOB_DISTRICT="neon_market"
JOB_TIER=1
JOB_STRETCH=0
JOB_HAS_WATCHER=0

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir"
  local code
  code="$(seed_token "$JOB_ID" "dash" 8)"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    DASH-NAMED PAYLOAD
  ═══════════════════════════════════════════════════
  A file starts with a dash (ls will look weird). Read it with:
    cat ./-payload   or   cat -- -payload
  Write the DEFUSE= value to defused.txt, then complete.
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: ls -la ; cat ./-payload
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Read the dash-leading file and write DEFUSE value to defused.txt.
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

  cat > "$jobdir/-payload" <<EOF
# do not rm me casually
DEFUSE=${code}
EOF

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${code}"
if [[ ! -f defused.txt ]]; then
  echo "Write DEFUSE value to defused.txt (cat ./-payload)"
  exit 1
fi
got=\$(tr -d ' \\n\\r' < defused.txt)
if [[ "\$got" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "defused.txt wrong. cat ./-payload and copy DEFUSE value"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
