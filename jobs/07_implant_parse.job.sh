# jobs/07_implant_parse.job.sh — python stdlib
JOB_ID="implant_parse"
JOB_TITLE="Compile the Implant"
JOB_SKILL="python"
JOB_SPINE="netrunner"
JOB_REQUIRES=("python3")
JOB_DISTRICT="undergrid"
JOB_TIER=2
JOB_STRETCH=0
JOB_HAS_WATCHER=0

job_install() {
  local root="$1"
  local jobdir="$root/jobs/$JOB_ID"
  mkdir -p "$jobdir"
  local token
  token="$(seed_token "$JOB_ID" "implant" 12)"

  cat > "$jobdir/-" <<'EOF'
  ═══════════════════════════════════════════════════
    IMPLANT PARSE
  ═══════════════════════════════════════════════════
  payload.json holds segments. Write parse_implant.py that
  concatenates all "chunk" fields in order and writes the
  result to implant_key.txt. Run: python3 parse_implant.py
  then complete.
  ═══════════════════════════════════════════════════
EOF

  cat > "$jobdir/.hint" <<'EOF'
  HINT: import json; open payload.json; join chunk fields; write implant_key.txt
EOF

  cat > "$jobdir/.objective" <<'EOF'
  Parse payload.json with python3; write concatenated chunks to implant_key.txt.
EOF

  cat > "$jobdir/.job_meta" <<EOF
JOB_ID=$JOB_ID
JOB_TITLE=$JOB_TITLE
JOB_SKILL=$JOB_SKILL
JOB_SPINE=$JOB_SPINE
WORK_ROOT=jobs/$JOB_ID
JOB_REQUIRES=python3
JOB_STRETCH=0
JOB_HAS_WATCHER=0
EOF

  # Split token into chunks
  local c1 c2 c3
  c1="${token:0:4}"
  c2="${token:4:4}"
  c3="${token:8:4}"
  cat > "$jobdir/payload.json" <<EOF
{"segments":[{"chunk":"${c1}"},{"chunk":"${c2}"},{"chunk":"${c3}"}]}
EOF

  cat > "$jobdir/parse_implant.py" <<'PY'
#!/usr/bin/env python3
# Stub: read payload.json, join segment chunks, write implant_key.txt
import json
# TODO: implement
print("implement me")
PY

  cat > "$jobdir/.check_complete" <<EOF
#!/bin/bash
EXPECTED="${token}"
if [[ ! -f implant_key.txt ]]; then
  echo "Run python3 parse_implant.py to produce implant_key.txt"
  exit 1
fi
got=\$(tr -d ' \\n\\r' < implant_key.txt)
if [[ "\$got" == "\$EXPECTED" ]]; then
  exit 0
fi
echo "implant_key.txt does not match. Join all chunk fields from payload.json"
exit 1
EOF
  chmod +x "$jobdir/.check_complete"
}
