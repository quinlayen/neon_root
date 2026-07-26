# jobs/06_archive_drop.job.sh — tar
JOB_ID="archive_drop"
JOB_TITLE="Untar the Dead Drop"
JOB_SKILL="shell"
JOB_SPINE="resistance"
JOB_REQUIRES=()
JOB_DISTRICT="dockside"
JOB_TIER=1
JOB_STRETCH=0
JOB_HAS_WATCHER=0

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir/staging"
  local code
  code="$(seed_token "$JOB_ID" "drop" 8)"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    DEAD DROP ARCHIVE
  ═══════════════════════════════════════════════════
  Extract drop.tar with tar. Read the intel file inside.
  Write the CODE= value to drop_code.txt, then complete.
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: tar -tf drop.tar ; tar -xf drop.tar
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Untar drop.tar, recover CODE from the intel file, write drop_code.txt.
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

  printf 'CODE=%s\n' "$code" > "$jobdir/staging/intel.txt"
  (cd "$jobdir" && tar -cf drop.tar staging/intel.txt)
  rm -rf "$jobdir/staging"

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${code}"
if [[ ! -f drop_code.txt ]]; then
  echo "Extract drop.tar and write CODE value to drop_code.txt"
  exit 1
fi
got=\$(tr -d ' \\n\\r' < drop_code.txt)
if [[ "\$got" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "drop_code.txt wrong. tar -xf drop.tar and read intel"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
