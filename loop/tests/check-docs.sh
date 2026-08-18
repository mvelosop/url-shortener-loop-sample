#!/usr/bin/env bash
# Documentation paths, checked rather than re-read.
#
# Two failure modes, and the second is the one that actually happens: a link
# that points nowhere, and a doc that still describes a layout the loop has
# moved on from. Four stale references accumulated in two days of work here.
#
#   loop/tests/check-docs.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
fail=0

# This checks THIS repo's documentation. In a consumer repo the loop's own
# README legitimately cites briefs and design notes that were never installed,
# so there is nothing here to check and flagging it would be noise.
#
# loop/.installed is the marker because the INSTALLER writes it: its presence
# positively identifies a vendored copy. Keying on the absence of some file
# this repo happens to have would mean the check silently stops running here
# the day that file moves.
if [[ -f loop/.installed ]]; then
  echo "docs check skipped — this is an installed copy (loop/.installed present)"
  exit 0
fi

# 1. every backticked path must resolve — relative to its own doc, to the repo
#    root, or as a bare filename that exists somewhere. NNN/<x> are templates.
python3 - <<'PY' || fail=1
import re, pathlib, sys
root = pathlib.Path('.').resolve()
names = {p.name for p in root.rglob('*') if '/.git/' not in str(p)}
docs = [p for p in root.rglob('*.md')
        if '/.git/' not in str(p) and 'docs/references' not in str(p)
        and 'loop/runs' not in str(p) and 'loop/journals' not in str(p)]
pat = re.compile(r'`([A-Za-z0-9_./-]+\.(?:md|sh|json|py|jsonl|toml))`')
bad = []
for d in docs:
    for m in pat.finditer(d.read_text()):
        r = m.group(1)
        if r.startswith(('~', 'http')) or 'NNN' in r or '<' in r: continue
        if (d.parent / r).exists() or (root / r).exists() or r.split('/')[-1] in names: continue
        bad.append((d.relative_to(root), r))
for d, r in bad: print(f"  dead path  {d}: {r}")
sys.exit(1 if bad else 0)
PY

# 2. layouts the loop has retired must not be described as current
retired=(
  "loop/journal.md|one journal per plan lives at loop/journals/<plan-id>.md"
  "loop/runs/<run-id>|run dirs are branch-scoped: loop/runs/<branch>/<run-id>"
  "loop/runs/<timestamp>|run dirs are branch-scoped: loop/runs/<branch>/<timestamp>"
)
for entry in "${retired[@]}"; do
  patt="${entry%%|*}"; why="${entry##*|}"
  hits="$(grep -rn -F "$patt" --include='*.md' . 2>/dev/null \
          | grep -v './docs/references/\|./loop/runs/\|./loop/journals/' || true)"
  if [[ -n "$hits" ]]; then
    echo "  retired layout '$patt' still documented — $why"
    echo "$hits" | sed 's/^/      /'; fail=1
  fi
done

# 3. counts claimed in prose must match reality. Four documents drifted to
#    three different numbers in two days; nothing else would have caught it.
actual=$(( $(ls loop/tests/scenarios/*.sh 2>/dev/null | wc -l) + 2 ))
claimed="$(grep -rhoE '[0-9]+[ -](scenario|check)s?' --include='*.md' . 2>/dev/null \
  | grep -v './docs/references/' | grep -oE '^[0-9]+' | sort -u)"
for c in $claimed; do
  if [[ "$c" != "$actual" ]]; then
    echo "  docs claim $c checks, the suite has $actual"
    grep -rn "$c scenario\|$c check\|$c-scenario\|$c-check" --include='*.md' . 2>/dev/null \
      | grep -v './docs/references/\|./loop/runs/\|./loop/journals/' | sed 's/^/      /'
    fail=1
  fi
done

[[ $fail -eq 0 ]] && echo "docs ok — every path resolves, no retired layout described" || echo "docs FAILED"
exit $fail
