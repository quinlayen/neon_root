# jobs/09_git_stash_drop.job.sh — git stash
JOB_ID="git_stash_drop"
JOB_TITLE="Pull the Stash Drop"
JOB_SKILL="git"
JOB_SPINE="mole"
JOB_REQUIRES=("git")
JOB_DISTRICT="archive_stack"
JOB_TIER=2
JOB_STRETCH=0
JOB_HAS_WATCHER=0

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir/drop"
  local secret
  secret="$(seed_token "$JOB_ID" "stash" 8)"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    STASH DROP (git)
  ═══════════════════════════════════════════════════
  drop/ is a git repo with a stash. Recover stash_note.txt
  contents (STASH= value) into recovered_stash.txt, complete.
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: cd drop; git stash list; git stash show -p; git stash pop
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Recover stashed stash_note.txt; write STASH value to recovered_stash.txt.
EOF

  cat > "$jobdir/.job_meta" <<EOF
JOB_ID=$JOB_ID
JOB_TITLE=$JOB_TITLE
JOB_SKILL=$JOB_SKILL
JOB_SPINE=$JOB_SPINE
WORK_ROOT=jobs/$JOB_ID
JOB_REQUIRES=git
JOB_STRETCH=0
JOB_HAS_WATCHER=0
EOF

  (
    cd "$jobdir/drop" || exit 1
    git init -q
    printf 'base\n' > README
    git -c user.email=runner@neon.local -c user.name='Neon Root' add README
    git -c user.email=runner@neon.local -c user.name='Neon Root' commit -q -m "base"
    printf 'STASH=%s\n' "$secret" > stash_note.txt
    git -c user.email=runner@neon.local -c user.name='Neon Root' stash push -q -u -m "mole drop" -- stash_note.txt
    rm -f stash_note.txt
  )

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${secret}"
if [[ ! -f recovered_stash.txt ]]; then
  echo "Recover STASH value into recovered_stash.txt via git stash"
  exit 1
fi
got=\$(tr -d ' \\n\\r' < recovered_stash.txt)
got2=\${got#STASH=}
if [[ "\$got" == "\$EXPECTED" || "\$got2" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "recovered_stash.txt wrong. git stash list / show -p in drop/"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
