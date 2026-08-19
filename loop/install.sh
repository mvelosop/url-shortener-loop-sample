#!/usr/bin/env bash
#
# Install this loop into another repo.
#
#   loop/install.sh /path/to/target-repo
#
# The loop is two things with different homes, which is why there is no clean
# submodule or plugin route: the SKILLS must sit at .claude/skills/ for Claude
# Code to resolve `/loop-work T3`, and the DRIVER is a shell script you run from
# your terminal. So it is vendored — but vendored deliberately, with a version
# stamp and a proof it works.
#
# Three classes of file, handled differently:
#
#   loop-owned    loop/, .claude/skills/loop-*   overwritten — these ARE the loop
#   shared        .claude/settings.json, CLAUDE.md   MERGED, never clobbered
#   yours         everything else                never touched
#
# Idempotent: re-run to update an existing install.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"

say()  { printf '\033[36m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[install]\033[0m %s\n' "$*"; }
die()  { printf '\033[31m[install] %s\033[0m\n' "$*" >&2; exit 1; }

[[ -n "$TARGET" ]] || die "usage: loop/install.sh /path/to/target-repo"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd -P)" || die "no such directory: ${1}"
[[ "$TARGET" != "$SRC" ]] || die "target is the loop's own repo"
[[ -d "$TARGET/.git" ]] || die "$TARGET is not a git repository (the loop commits per iteration)"
command -v jq >/dev/null 2>&1 || die "jq is required"

say "installing the loop into $(basename "$TARGET")"

# ---- loop-owned: overwrite ------------------------------------------------

mkdir -p "$TARGET/loop" "$TARGET/.claude/skills" "$TARGET/docs/briefs"
# Every script, not a hand-kept list: amend.sh was added after this installer
# and silently never shipped, so consumers got a manual documenting a file they
# did not have.
for f in "$SRC"/loop/*.sh; do
  cp "$f" "$TARGET/loop/$(basename "$f")"
  chmod +x "$TARGET/loop/$(basename "$f")"
done
cp "$SRC/loop/README.md" "$SRC/loop/brief-template.md" "$TARGET/loop/"
rm -rf "$TARGET/loop/tests"
cp -R "$SRC/loop/tests" "$TARGET/loop/tests"
for s in loop-plan loop-work loop-review; do
  rm -rf "$TARGET/.claude/skills/$s"
  cp -R "$SRC/.claude/skills/$s" "$TARGET/.claude/skills/$s"
done
say "  loop/ and .claude/skills/loop-* installed"

# ---- shared: merge --------------------------------------------------------
#
# The deny list is the load-bearing half and is always safe to add to. The
# allow list is per-stack: only the loop's own needs are merged in, and the
# stack-specific entries are reported for you to choose rather than assumed.

LOOP_ALLOW='["Read","Glob","Grep","Edit","Write","TodoWrite",
  "Bash(git status:*)","Bash(git diff:*)","Bash(git log:*)","Bash(git show:*)",
  "Bash(ls:*)","Bash(cat:*)","Bash(head:*)","Bash(tail:*)","Bash(wc:*)",
  "Bash(find:*)","Bash(mkdir:*)","Bash(jq:*)"]'
LOOP_DENY='["Bash(git push:*)","Bash(git commit:*)","Bash(git reset:*)","Bash(git clean:*)",
  "Bash(rm -rf:*)","Bash(sudo:*)","Bash(curl:*)","Bash(wget:*)","Bash(claude:*)",
  "Bash(loop/run.sh:*)","Read(~/.claude/**)","Edit(~/.claude/**)","Write(~/.claude/**)",
  "WebFetch","WebSearch"]'

TS="$TARGET/.claude/settings.json"
if [[ -f "$TS" ]] && jq -e . "$TS" >/dev/null 2>&1; then
  tmp="$(mktemp)"
  jq --argjson a "$LOOP_ALLOW" --argjson d "$LOOP_DENY" \
    '.permissions.allow = ((.permissions.allow // []) + $a | unique)
     | .permissions.deny = ((.permissions.deny // []) + $d | unique)' "$TS" >"$tmp" \
    && mv "$tmp" "$TS" && say "  .claude/settings.json merged (yours kept, loop rules added)"
else
  jq -n --argjson a "$LOOP_ALLOW" --argjson d "$LOOP_DENY" \
    '{"$schema":"https://json.schemastore.org/claude-code-settings.json",
      includeCoAuthoredBy:false, permissions:{allow:$a, deny:$d}}' >"$TS"
  say "  .claude/settings.json created"
fi

TC="$TARGET/CLAUDE.md"
BEGIN='<!-- loop:begin -->'
END='<!-- loop:end -->'
rules="$(sed -n "/^## Rules for any session working here$/,/^## Toolchain$/p" "$SRC/CLAUDE.md" | sed '$d')"
block="$BEGIN
$rules
Loop docs: \`loop/README.md\`. State lives in \`loop/state.json\`; the driver owns it.
$END"
if [[ -f "$TC" ]] && grep -q -- "$BEGIN" "$TC"; then
  python3 - "$TC" "$BEGIN" "$END" "$block" <<'PY'
import sys, pathlib, re
f, b, e, block = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
p = pathlib.Path(f); t = p.read_text()
p.write_text(re.sub(re.escape(b) + r".*?" + re.escape(e), lambda _: block, t, flags=re.S))
PY
  say "  CLAUDE.md loop section updated in place"
else
  printf '\n%s\n' "$block" >>"$TC"
  say "  CLAUDE.md loop section appended (nothing of yours changed)"
fi

for entry in ".DS_Store" "loop/proposal.json" "loop/verdict.json" "loop/.running"; do
  grep -qxF "$entry" "$TARGET/.gitignore" 2>/dev/null || echo "$entry" >>"$TARGET/.gitignore"
done

# ---- provenance -----------------------------------------------------------

jq -n --arg s "$(basename "$SRC")" --arg c "$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)" \
      --arg d "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{source:$s, commit:$c, installed:$d}' >"$TARGET/loop/.installed"
say "  stamped loop/.installed (source commit $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null))"

# ---- prove it -------------------------------------------------------------

say "running the loop's own suite in the target — this is the install test"
if ( cd "$TARGET" && loop/tests/run-all.sh >/tmp/install-suite.log 2>&1 ); then
  say "  $(grep -oE '[0-9]+ passed' /tmp/install-suite.log | tail -1) — the install works"
else
  warn "  suite did not pass; see /tmp/install-suite.log"
  grep -E '^  .\[31mFAIL' /tmp/install-suite.log | head -5
fi

cat <<NEXT

Installed. Two things are stack-specific and yours to set:

  1. .claude/settings.json — add the commands your gates need, e.g.
       "Bash(pnpm:*)"   "Bash(npm:*)"   "Bash(go:*)"   "Bash(cargo:*)"
     The loop itself never names a test runner: each task carries its own
     verify command, so the gate list is your plan's, not the loop's.

  2. CLAUDE.md — the loop section was added between the loop:begin/end
     markers. Add a toolchain note of your own above or below it.

Then:
  claude                     # once, interactively, and accept the trust dialog
  loop/run.sh docs/briefs/0001-your-brief.md
NEXT
