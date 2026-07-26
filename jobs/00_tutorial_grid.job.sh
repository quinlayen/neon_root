# jobs/00_tutorial_grid.job.sh
JOB_ID="tutorial_grid"
JOB_TITLE="Jack Into the Grid"
JOB_SKILL="shell"
JOB_SPINE="netrunner"
JOB_REQUIRES=()
JOB_DISTRICT="dockside"
JOB_TIER=0
JOB_STRETCH=0
JOB_HAS_WATCHER=0

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir"

  local code
  code="$(seed_token "$JOB_ID" "welcome" 8)"

  cat > "$jobdir/-" <<EOF
  ═══════════════════════════════════════════════════
    SAFEHOUSE UPLINK — TUTORIAL
  ═══════════════════════════════════════════════════
  Your deck is hot. Read every file. The uplink code is:

    ${code}

  Write it into the file jack_confirm.txt in this directory
  (single line, exact code), then run:  complete
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: Use cat on files you see with ls. Create jack_confirm.txt
  with the code from the room description (- file). try: complete
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Accept this contract, read the room file (-), write jack_confirm.txt
  containing the uplink code, then run complete.
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

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${code}"
if [[ ! -f jack_confirm.txt ]]; then
  echo "Create jack_confirm.txt with the uplink code from the room text."
  exit 1
fi
got=\$(tr -d ' \\n\\r' < jack_confirm.txt)
if [[ "\$got" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "jack_confirm.txt does not match the uplink code. Read the room file (-) again."
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
