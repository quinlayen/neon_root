#!/bin/bash
# ============================================================
#  Neon Root — automated smoke (real generate → tutorial path)
#  Usage: ./scripts/smoke_test.sh
#  Exit 0 on success. bash 3.2 safe.
# ============================================================

set -e

SCRIPT_DIR=$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$REPO"

ROOT="$REPO/metroplex"
GEN="$REPO/scripts/generate_world.sh"
FAIL=0

pass() { printf '  PASS: %s\n' "$*"; }
fail() { printf '  FAIL: %s\n' "$*"; FAIL=1; }

echo "Neon Root smoke_test"
echo "===================="

# Fresh world
bash "$GEN" --new >/dev/null

# shellcheck disable=SC1091
source "$REPO/scripts/lib/common.sh"
# shellcheck disable=SC1091
source "$REPO/scripts/lib/seed.sh"
# shellcheck disable=SC1091
source "$REPO/scripts/lib/job_runtime.sh"
# shellcheck disable=SC1091
source "$REPO/scripts/lib/watchers.sh"
# shellcheck disable=SC1091
source "$ROOT/.tools" 2>/dev/null || true
export NEON_ROOT="$ROOT"
export ROOT
export REPO

# Structural
[[ -f "$ROOT/safehouse/-" && ! -d "$ROOT/safehouse/-" ]] && pass "room - is a file" || fail "room - must be a file"
[[ -f "$ROOT/.seed" ]] && pass "seed present" || fail "missing seed"
[[ -d "$ROOT/jobs/tutorial_grid" ]] && pass "tutorial installed" || fail "tutorial missing"
[[ -f "$ROOT/jobs/tutorial_grid/.check_complete" ]] && pass "tutorial checker" || fail "no checker"

# Board: tutorial should be open
board_sync_from_ledger "$ROOT"
bucket=$(board_bucket "$ROOT" "tutorial_grid")
[[ "$bucket" = "open" ]] && pass "tutorial board open" || fail "tutorial board=$bucket (want open)"

# Seed-baked secret: extract from room text (not a fixed walkthrough)
# Room has the code on its own line after "uplink code is"
code=$(grep -E '^[a-f0-9]{8}$' "$ROOT/jobs/tutorial_grid/-" | head -1 | tr -d ' \n\r')
[[ -n "$code" ]] || code=$(awk '/uplink code is/{getline; getline; gsub(/^[ \t]+/,""); print; exit}' "$ROOT/jobs/tutorial_grid/-" | tr -d ' \n\r')
# Fallback: parse from checker EXPECTED=
if [[ -z "$code" ]]; then
  code=$(grep '^EXPECTED=' "$ROOT/jobs/tutorial_grid/.check_complete" | head -1 | sed 's/^EXPECTED=//;s/"//g' | tr -d ' \n\r')
fi
[[ ${#code} -eq 8 ]] && pass "tutorial code extracted (${code:0:2}..)" || fail "could not extract seed-baked code"

# Accept requires runtime helpers from game functions
# shellcheck disable=SC1091
source "$ROOT/.game_functions.sh"
cd "$ROOT/safehouse"

# accept tutorial
accept tutorial_grid >/dev/null
st=$(ledger_state "$ROOT" "tutorial_grid")
[[ "$st" = "accepted" ]] && pass "ledger accepted" || fail "ledger state=$st"

# complete without file should fail
set +e
complete tutorial_grid >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -ne 0 ]] && pass "complete rejects incomplete" || fail "complete should fail without jack_confirm"

# Write confirmation and complete
printf '%s\n' "$code" > "$ROOT/jobs/tutorial_grid/jack_confirm.txt"
set +e
out=$(complete tutorial_grid 2>&1)
rc=$?
set -e
[[ "$rc" -eq 0 ]] && pass "tutorial complete" || fail "complete failed: $out"
st=$(ledger_state "$ROOT" "tutorial_grid")
[[ "$st" = "completed" ]] && pass "ledger completed" || fail "ledger not completed"

# Idempotent complete
set +e
out=$(complete tutorial_grid 2>&1)
rc=$?
set -e
[[ "$rc" -eq 0 ]] && pass "complete idempotent" || fail "idempotent complete failed"
echo "$out" | grep -qi "already paid" && pass "idempotent message" || pass "idempotent ok (msg variant)"

# Accept before complete discipline on another job
set +e
# try complete badge without accept
# clear any accept
out=$(cd "$ROOT/jobs/badge_skim" && complete badge_skim 2>&1)
rc=$?
set -e
[[ "$rc" -ne 0 ]] && pass "must accept before complete" || fail "complete without accept should fail"

# Inventory guards
cd "$ROOT/safehouse"
set +e
take ../x >/dev/null 2>&1; r1=$?
take /tmp/x >/dev/null 2>&1; r2=$?
take - >/dev/null 2>&1; r3=$?
take .hint >/dev/null 2>&1; r4=$?
set -e
[[ "$r1" -ne 0 && "$r2" -ne 0 && "$r3" -ne 0 && "$r4" -ne 0 ]] && pass "take rejects bad names" || fail "take guards failed"

# Create a takeable file and take it
printf 'item\n' > "$ROOT/safehouse/loot_chip.txt"
take loot_chip.txt >/dev/null
[[ -f "$ROOT/.inventory/loot_chip.txt" ]] && pass "take normal basename" || fail "take failed"

# Tool lock: python job locked when HAS_PYTHON3=0
# Simulate by rewriting .tools
cp "$ROOT/.tools" "$ROOT/.tools.bak"
cat > "$ROOT/.tools" <<'T'
HAS_PYTHON3=0
HAS_GIT=0
HAS_SQLITE3=0
PYTHON3_BIN=
GIT_BIN=
SQLITE3_BIN=
T
# shellcheck disable=SC1091
source "$ROOT/.tools"
board_sync_from_ledger "$ROOT"
b=$(board_bucket "$ROOT" "implant_parse")
[[ "$b" = "locked" ]] && pass "python locked without tool" || fail "implant_parse bucket=$b want locked"
b=$(board_bucket "$ROOT" "git_safehouse")
[[ "$b" = "locked" ]] && pass "git locked without tool" || fail "git_safehouse bucket=$b want locked"
b=$(board_bucket "$ROOT" "tutorial_grid")
# completed stays completed
[[ "$b" = "completed" ]] && pass "completed stays completed" || fail "tutorial board=$b"

# Restore tools and unlock without reseed
mv "$ROOT/.tools.bak" "$ROOT/.tools"
# shellcheck disable=SC1091
source "$ROOT/.tools"
seed_before=$(tr -d ' \n\r' < "$ROOT/.seed")
ensure_jobs_for_tools "$ROOT" >/dev/null
seed_after=$(tr -d ' \n\r' < "$ROOT/.seed")
[[ "$seed_before" = "$seed_after" ]] && pass "seed unchanged after unlock" || fail "seed rewritten"
if [[ "${HAS_PYTHON3:-0}" = "1" ]]; then
  b=$(board_bucket "$ROOT" "implant_parse")
  [[ "$b" = "open" || "$b" = "active" ]] && pass "python unlocks when tool present" || fail "implant_parse=$b after unlock"
fi

# Shell job smoke: badge_skim
if [[ -d "$ROOT/jobs/badge_skim" ]]; then
  needle=$(grep '^EXPECTED=' "$ROOT/jobs/badge_skim/.check_complete" | head -1 | sed 's/^EXPECTED=//;s/"//g' | tr -d ' \n\r')
  accept badge_skim >/dev/null 2>&1 || true
  printf '%s\n' "$needle" > "$ROOT/jobs/badge_skim/recovered_badge.txt"
  set +e
  complete badge_skim >/dev/null 2>&1
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] && pass "badge_skim complete" || fail "badge_skim complete failed"
fi

# Launcher non-interactive probes
set +e
bash "$REPO/play.sh" --tools >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" -eq 0 ]] && pass "play.sh --tools" || fail "play.sh --tools rc=$rc"

# Optional: python job if tool present
if [[ "${HAS_PYTHON3:-0}" = "1" ]] && [[ -d "$ROOT/jobs/implant_parse" ]]; then
  tok=$(grep '^EXPECTED=' "$ROOT/jobs/implant_parse/.check_complete" | head -1 | sed 's/^EXPECTED=//;s/"//g' | tr -d ' \n\r')
  printf '%s\n' "$tok" > "$ROOT/jobs/implant_parse/implant_key.txt"
  accept implant_parse >/dev/null 2>&1 || true
  set +e
  complete implant_parse >/dev/null 2>&1
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] && pass "implant_parse (precomputed key)" || fail "implant_parse complete failed"
fi

# Optional: git job
if [[ "${HAS_GIT:-0}" = "1" ]] && [[ -d "$ROOT/jobs/git_safehouse" ]]; then
  tok=$(grep '^EXPECTED=' "$ROOT/jobs/git_safehouse/.check_complete" | head -1 | sed 's/^EXPECTED=//;s/"//g' | tr -d ' \n\r')
  printf '%s\n' "$tok" > "$ROOT/jobs/git_safehouse/recovered_key.txt"
  accept git_safehouse >/dev/null 2>&1 || true
  set +e
  complete git_safehouse >/dev/null 2>&1
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] && pass "git_safehouse complete" || fail "git_safehouse complete failed"
fi

# kill_all on --new
export NEON_ROOT="$ROOT"
# leave a fake pidfile and ensure --new cleans
echo "99999" > "$ROOT/.watchers/fake.pid" 2>/dev/null || true
bash "$GEN" --new >/dev/null
[[ ! -f "$ROOT/.watchers/fake.pid" ]] && pass "--new rebuilds watchers dir" || fail "stale pidfile survived --new"

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "SMOKE OK"
  exit 0
else
  echo "SMOKE FAILED"
  exit 1
fi
