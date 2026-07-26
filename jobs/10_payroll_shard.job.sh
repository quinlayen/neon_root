# jobs/10_payroll_shard.job.sh — SQL stretch
JOB_ID="payroll_shard"
JOB_TITLE="Query the Payroll Shard"
JOB_SKILL="sql"
JOB_SPINE="netrunner"
JOB_REQUIRES=("sqlite3")
JOB_DISTRICT="corp_shard"
JOB_TIER=3
JOB_STRETCH=1
JOB_HAS_WATCHER=0

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir"
  local secret
  secret="$(seed_token "$JOB_ID" "payroll" 8)"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    PAYROLL SHARD (stretch)
  ═══════════════════════════════════════════════════
  payroll.db is a local sqlite database.
  Find the employee with role='shadow_admin' and write
  their access_code to admin_code.txt, then complete.
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: sqlite3 payroll.db "SELECT access_code FROM employees WHERE role='shadow_admin';"
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Query payroll.db for shadow_admin access_code; write admin_code.txt.
EOF

  cat > "$jobdir/.job_meta" <<EOF
JOB_ID=$JOB_ID
JOB_TITLE=$JOB_TITLE
JOB_SKILL=$JOB_SKILL
JOB_SPINE=$JOB_SPINE
WORK_ROOT=jobs/$JOB_ID
JOB_REQUIRES=sqlite3
JOB_STRETCH=1
JOB_HAS_WATCHER=0
EOF

  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$jobdir/payroll.db" <<SQL
CREATE TABLE employees (name TEXT, role TEXT, access_code TEXT);
INSERT INTO employees VALUES ('alice','analyst','pub1');
INSERT INTO employees VALUES ('bob','ops','pub2');
INSERT INTO employees VALUES ('cipher','shadow_admin','${secret}');
INSERT INTO employees VALUES ('dan','intern','pub3');
SQL
  else
    # Minimal placeholder so content exists when tool missing
    printf 'placeholder — install sqlite3 and re-run ./play.sh --new for real db\n' > "$jobdir/payroll.db.missing"
    # Still create empty file named payroll.db for structure
    : > "$jobdir/payroll.db"
  fi

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${secret}"
if [[ ! -f admin_code.txt ]]; then
  echo "Query payroll.db and write access_code to admin_code.txt"
  exit 1
fi
got=\$(tr -d ' \\n\\r' < admin_code.txt)
if [[ "\$got" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "admin_code.txt wrong. SELECT access_code FROM employees WHERE role='shadow_admin';"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
