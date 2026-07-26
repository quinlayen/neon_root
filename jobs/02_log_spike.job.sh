# jobs/02_log_spike.job.sh — pipes / sort / uniq
JOB_ID="log_spike"
JOB_TITLE="Spike the Noise Log"
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
  local top
  top="$(seed_token "$JOB_ID" "topip" 8)"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    NOISE LOG SPIKE
  ═══════════════════════════════════════════════════
  access.log has many IP hits. Find the MOST frequent IP
  (sort | uniq -c | sort -nr). Write it to top_ip.txt, then complete.
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: sort access.log | uniq -c | sort -nr | head
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Identify the most frequent IP in access.log; write it to top_ip.txt.
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

  # Winner IP is the seed token string (most frequent line). No seq (not on all PATH cuts).
    {
    local i
    i=0
    while [[ $i -lt 20 ]]; do echo "${top}"; i=$((i + 1)); done
    i=0
    while [[ $i -lt 5 ]]; do echo "noise.ip.1"; i=$((i + 1)); done
    i=0
    while [[ $i -lt 3 ]]; do echo "noise.ip.2"; i=$((i + 1)); done
  } > "$jobdir/access.log"

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${top}"
if [[ ! -f top_ip.txt ]]; then
  echo "Write the most frequent IP into top_ip.txt"
  exit 1
fi
got=\$(tr -d ' \\n\\r' < top_ip.txt)
if [[ "\$got" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "top_ip.txt wrong. Use sort | uniq -c | sort -nr on access.log"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
