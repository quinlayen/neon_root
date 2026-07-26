# jobs/03_perm_gate.job.sh — chmod lock
JOB_ID="perm_gate"
JOB_TITLE="Crack the Perimeter Gate"
JOB_SKILL="shell"
JOB_SPINE="mole"
JOB_REQUIRES=()
JOB_DISTRICT="helix_perimeter"
JOB_TIER=1
JOB_STRETCH=0
JOB_HAS_WATCHER=0

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir/locked_vault"
  local secret
  secret="$(seed_token "$JOB_ID" "gate" 8)"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    PERIMETER GATE
  ═══════════════════════════════════════════════════
  locked_vault/ is mode 000. Open it (chmod), read gate_code.txt
  inside, write the code to unlocked_code.txt here, then complete.
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: chmod u+rwx locked_vault   then cat locked_vault/gate_code.txt
EOF

  cat > "$jobdir/.objective" <<'EOF'
  chmod the locked_vault, recover gate_code.txt, write unlocked_code.txt.
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

  printf '%s\n' "$secret" > "$jobdir/locked_vault/gate_code.txt"
  chmod 000 "$jobdir/locked_vault"

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${secret}"
if [[ ! -f unlocked_code.txt ]]; then
  echo "Write the gate code to unlocked_code.txt after opening locked_vault"
  exit 1
fi
got=\$(tr -d ' \\n\\r' < unlocked_code.txt)
if [[ "\$got" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "unlocked_code.txt does not match. chmod the vault and re-read gate_code.txt"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
