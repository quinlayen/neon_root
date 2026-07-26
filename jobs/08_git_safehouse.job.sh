# jobs/08_git_safehouse.job.sh — git history
JOB_ID="git_safehouse"
JOB_TITLE="Restore the Burned Vault"
JOB_SKILL="git"
JOB_SPINE="resistance"
JOB_REQUIRES=("git")
JOB_DISTRICT="archive_stack"
JOB_TIER=2
JOB_STRETCH=0
JOB_HAS_WATCHER=0

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir/vault"
  local secret
  secret="$(seed_token "$JOB_ID" "vault" 8)"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    BURNED VAULT (git)
  ═══════════════════════════════════════════════════
  vault/ is a git repo. HEAD deleted the secret file.
  Recover vault_key.txt from history (git log / show / checkout).
  Copy the KEY= value to recovered_key.txt in this job dir, complete.
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: cd vault; git log --oneline; git show HEAD~1:vault_key.txt
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Recover deleted vault_key.txt from git history; write KEY to recovered_key.txt.
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

  # Full repo only when git is available; never abort world gen without git.
  if command -v git >/dev/null 2>&1; then
    rm -rf "$jobdir/vault"
    mkdir -p "$jobdir/vault"
    (
      cd "$jobdir/vault" || exit 1
      git init -q
      git -c user.email=runner@neon.local -c user.name='Neon Root' checkout -q -b main 2>/dev/null || true
      printf 'KEY=%s\n' "$secret" > vault_key.txt
      git -c user.email=runner@neon.local -c user.name='Neon Root' add vault_key.txt
      git -c user.email=runner@neon.local -c user.name='Neon Root' commit -q -m "store vault key"
      rm -f vault_key.txt
      git -c user.email=runner@neon.local -c user.name='Neon Root' add -A
      git -c user.email=runner@neon.local -c user.name='Neon Root' commit -q -m "burn the vault"
    )
    rm -f "$jobdir/.git_install_pending"
  else
    cat > "$jobdir/vault/README.locked" <<'EOF'
  Git was not available when this contract was installed.
  Install git, then re-run ./play.sh (ensure will rebuild the vault) or ./play.sh --new.
EOF
    touch "$jobdir/.git_install_pending"
  fi

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${secret}"
if [[ ! -f recovered_key.txt ]]; then
  echo "Recover KEY from vault git history into recovered_key.txt"
  exit 1
fi
got=\$(tr -d ' \\n\\r' < recovered_key.txt)
if [[ "\$got" == "\$EXPECTED" || "\$got" == "KEY=\$EXPECTED" ]]; then
  exit 0
fi
got2=\${got#KEY=}
if [[ "\$got2" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "recovered_key.txt wrong. git log / git show in vault/"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
