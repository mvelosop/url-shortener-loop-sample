#!/usr/bin/env bash
#
# Check a brief before you spend anything on it.
#
#   loop/check-brief.sh docs/briefs/0003-runstat-cli.md
#   loop/check-brief.sh docs/briefs/*.md
#
# The brief is the highest-leverage artefact in the loop: every gate the planner
# writes is derived from it, and a vague brief produces weak gates that quietly
# lower the bar for the whole run. It was also, until this script, the only
# major artefact with no validation at all — the plan, the docs, the driver and
# the reviewer all have one.
#
# This checks the structure a brief needs. It cannot check the thing that
# matters most, which is whether the brief pins DECISIONS and leaves MECHANICS
# open. That stays a judgement, and the manual's "Writing a brief" section is
# where it lives. A brief can pass every check here and still be bad.
#
# Exit 0 clean, 1 with problems. Warnings do not fail.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

fails=0

check_one() {
  local f="$1" problems=0 warnings=0
  local body; body="$(cat "$f")"

  # Only briefs that declare themselves plannable are checked. A discussion
  # document or a finished design record is not a worse brief, it is a
  # different kind of document, and flagging it forever teaches people to
  # ignore the checker. Positive marker, not an inference from absence.
  # tolerate the metadata being written as a list; it is the same statement
  if ! grep -qiE '^[-*]? *\*\*Status:\*\* *(ready to plan|ready to execute)' <<<"$body"; then
    printf '\n\033[1m%s\033[0m\n  \033[36m-\033[0m skipped: not marked "ready to plan"\n' "$f"
    return
  fi

  printf '\n\033[1m%s\033[0m\n' "$f"

  bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; problems=$((problems+1)); }
  warn() { printf '  \033[33m!\033[0m %s\n' "$*"; warnings=$((warnings+1)); }
  ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }

  # A worked example is what arbitrates when two implementations disagree, and
  # what becomes the end-to-end acceptance test.
  if grep -qiE '^#+ .*(worked example|acceptance)' <<<"$body"; then ok "has a worked example"
  else bad "no worked example section — nothing arbitrates a disagreement"; fi

  # ...and it has to contain concrete values, not a description of some.
  if grep -qE '^```' <<<"$body"; then ok "has a fenced block with concrete values"
  else bad "no fenced code block — the worked example needs exact values, not prose"; fi

  # The out-of-scope list is how scope creep becomes a finding rather than a
  # matter of taste. The reviewer catches that shape; it needs something to cite.
  if grep -qiE '^#+ .*out of scope' <<<"$body"; then
    local n; n="$(awk '/^#+ .*[Oo]ut of scope/{f=1;next} f&&/^#+ /{exit} f' <<<"$body" | grep -c '^[-*] ')"
    if [[ "$n" -ge 2 ]]; then ok "out of scope: $n item(s)"
    else bad "out-of-scope section has $n item(s) — name what you are NOT asking for"; fi
  else bad "no out-of-scope section — scope creep has nothing to be measured against"; fi

  grep -qiE '^#+ .*constraint' <<<"$body" && ok "has constraints" \
    || warn "no constraints section — toolchain and limits are left to guesswork"

  # A task count calibrates decomposition.
  if grep -qiE '[0-9]+ (to|–|-) ?[0-9]* ?tasks|[a-z]+ to [a-z]+ tasks|[0-9]+ tasks' <<<"$body"; then
    ok "states an expected task count"
  else warn "no expected task count — decomposition has nothing to calibrate against"; fi

  # A precise behaviour contract almost always pins codes of some kind.
  if grep -qiE 'exit (code|[0-9])|\b(200|201|302|400|404|409|500)\b|exits? [0-9]' <<<"$body"; then
    ok "pins exit or status codes"
  else warn "no exit/status codes — is the behaviour contract precise enough to gate?"; fi

  # Hard rule 2, and briefs get published.
  if grep -qE '/Users/|/home/[a-z]' <<<"$body"; then
    bad "contains an absolute home path"
  else ok "no absolute paths"; fi

  # Pinning internal structure is the planner's job where the brief is silent;
  # a brief that does it has chosen mechanics, which is worth a second look.
  local pinned; pinned="$(grep -coE '`[a-z_]+\.(py|ts|js)::|`[a-z_]+\.[a-z_]+\(\)' <<<"$body" || true)"
  [[ "${pinned:-0}" -gt 2 ]] && warn "names $pinned internal symbols — pinning mechanics, not decisions?"

  # Every referenced path should resolve, or be an obvious template.
  local dead=0 r
  while read -r r; do
    [[ -n "$r" ]] || continue
    [[ "$r" == ~* || "$r" == http* || "$r" == *NNN* || "$r" == *'<'* ]] && continue
    # repo path, doc-relative, or a bare filename that exists somewhere: a
    # worked example legitimately names fixture files rather than repo paths
    [[ -e "$r" || -e "$(dirname "$f")/$r" ]] && continue
    find . -name "$(basename "$r")" -not -path './.git/*' -print -quit 2>/dev/null | grep -q . && continue
    warn "path does not resolve: $r"; dead=$((dead+1))
  done < <(grep -oE '`[A-Za-z0-9_./-]+\.(md|sh|json|py|ts|jsonl|toml)`' <<<"$body" | tr -d '`' | sort -u)
  [[ "$dead" -eq 0 ]] && ok "referenced paths resolve"

  if [[ $problems -gt 0 ]]; then
    printf '  \033[31m%d problem(s)\033[0m, %d warning(s)\n' "$problems" "$warnings"; fails=$((fails+1))
  else
    printf '  \033[32mok\033[0m, %d warning(s)\n' "$warnings"
  fi
}

[[ $# -gt 0 ]] || { echo "usage: loop/check-brief.sh <brief.md> [...]" >&2; exit 1; }
for f in "$@"; do
  [[ -f "$f" ]] || { echo "no such brief: $f" >&2; fails=$((fails+1)); continue; }
  check_one "$f"
done
printf '\n'
[[ $fails -eq 0 ]] && echo "briefs ok" || echo "$fails brief(s) need work"
exit $(( fails > 0 ? 1 : 0 ))
