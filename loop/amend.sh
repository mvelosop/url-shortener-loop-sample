#!/usr/bin/env bash
#
# Amend a plan between runs, safely.
#
#   loop/amend.sh check                      validate + re-render (run this after ANY edit)
#   loop/amend.sh verify   T4 '<command>'    replace a task's gate
#   loop/amend.sh reset    T4                back to pending, attempts 0
#   loop/amend.sh note     T4 '<text>'       leave a note the next session reads
#   loop/amend.sh drop     T4                remove a task (refuses if depended on)
#   loop/amend.sh show     [T4]              print the plan, or one task
#
# The plan is yours between runs and the driver's during one. Hand-editing
# state.json works — it is just JSON — but nothing tells you if you broke it,
# and the failure surfaces several minutes into the next run. So: every
# operation here validates and re-renders, and `check` does that alone for
# whatever you edited by hand.
#
# Deliberately small. Anything structural (re-scoping, adding tasks) is better
# done by editing the brief and re-planning than by patching state.

set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$REPO/loop/state.json"
cd "$REPO" || exit 1

say()  { printf '\033[36m[amend]\033[0m %s\n' "$*"; }
die()  { printf '\033[31m[amend] %s\033[0m\n' "$*" >&2; exit 1; }

[[ -f "$STATE" ]] || die "no plan at loop/state.json"
command -v jq >/dev/null || die "jq is required"

edit() {                       # atomic, like the driver's own writes
  local tmp; tmp="$(mktemp "$REPO/loop/.amend.XXXXXX")"
  jq "$@" "$STATE" >"$tmp" || { rm -f "$tmp"; die "edit failed"; }
  mv "$tmp" "$STATE"
}
has() { jq -e --arg id "$1" '[.tasks[]|select(.id==$id)]|length > 0' "$STATE" >/dev/null; }

check() {
  jq -e . "$STATE" >/dev/null 2>&1 || die "state.json is not valid JSON"
  local problems=0

  local n
  n="$(jq '[.tasks[]|select((.verify//"")=="")]|length' "$STATE")"
  [[ "$n" -eq 0 ]] || { say "  ✗ $n task(s) have no verify command"; problems=1; }
  n="$(jq '[.tasks[]|select(((.acceptance//[])|length)==0)]|length' "$STATE")"
  [[ "$n" -eq 0 ]] || { say "  ✗ $n task(s) have no acceptance criteria"; problems=1; }
  n="$(jq '[.tasks[].id] as $ids | [.tasks[]|.depends_on[]?|select(($ids|index(.))==null)]|length' "$STATE")"
  [[ "$n" -eq 0 ]] || { say "  ✗ $n dependency reference(s) name a task that does not exist"; problems=1; }
  # bind first: after `| length` the `.` inside a parenthesis is the array, not
  # the state — the same precedence trap that produced a phantom signal earlier
  n="$(jq '[.tasks[].id] as $ids | ($ids|length) - ($ids|unique|length)' "$STATE")"
  [[ "$n" -eq 0 ]] || { say "  ✗ duplicate task ids"; problems=1; }

  # A cycle means the driver never finds a ready task and stops as "blocked".
  # Resolve repeatedly: anything whose dependencies are all resolved joins the
  # set. If after N passes some task never joins, it is in a cycle.
  if ! jq -e '
      . as $s
      | reduce range(0; ($s.tasks|length)) as $_ ([];
          . as $done
          | $done + [ $s.tasks[] | select((((.depends_on)//[]) - $done) == []) | .id ]
          | unique)
      | length == ($s.tasks|length)' "$STATE" >/dev/null 2>&1; then
    say "  ✗ dependencies contain a cycle — no task would ever be ready"; problems=1
  fi

  # gates that already pass before the work exists are not gates
  local passing=() id cmd
  while read -r id; do
    [[ -n "$id" ]] || continue
    cmd="$(jq -r --arg i "$id" '.tasks[]|select(.id==$i)|.verify' "$STATE")"
    bash -c "$cmd" >/dev/null 2>&1 && passing+=("$id")
  done < <(jq -r '.tasks[]|select(.status=="pending")|.id' "$STATE")
  if [[ ${#passing[@]} -gt 0 ]]; then
    say "  ! pending task(s) whose gate already passes: ${passing[*]}"
    say "    a gate that is green before the work exists proves nothing"
  fi

  [[ $problems -eq 0 ]] || die "plan is not valid — fix the above, the next run would fail on it"
  "$REPO/loop/render-plan.sh" >/dev/null && say "  ✓ plan valid, loop/plan.md re-rendered"
}

cmd="${1:-check}"; shift || true
case "$cmd" in
  check) check ;;
  show)
    if [[ $# -ge 1 ]]; then jq --arg id "$1" '.tasks[]|select(.id==$id)' "$STATE"
    else jq -r '"\(.run_id)  \(.status)  \([.tasks[]|select(.status=="done")]|length)/\(.tasks|length) done\n" ,
                (.tasks[] | "  [\(if .status=="done" then "x" else " " end)] \(.id)  \(.title)")' "$STATE"; fi ;;
  verify)
    [[ $# -eq 2 ]] || die "usage: amend.sh verify <task-id> '<command>'"
    has "$1" || die "no such task: $1"
    edit --arg id "$1" --arg v "$2" '(.tasks[]|select(.id==$id)).verify = $v'
    say "$1 gate replaced"; check ;;
  reset)
    [[ $# -eq 1 ]] || die "usage: amend.sh reset <task-id>"
    has "$1" || die "no such task: $1"
    edit --arg id "$1" '(.tasks[]|select(.id==$id)) |= (.status="pending" | .attempts=0 | .notes="")'
    say "$1 reset to pending, attempts 0"; check ;;
  note)
    [[ $# -eq 2 ]] || die "usage: amend.sh note <task-id> '<text>'"
    has "$1" || die "no such task: $1"
    edit --arg id "$1" --arg n "$2" '(.tasks[]|select(.id==$id)).notes = $n'
    say "$1 note set"; check ;;
  drop)
    [[ $# -eq 1 ]] || die "usage: amend.sh drop <task-id>"
    has "$1" || die "no such task: $1"
    dep="$(jq -r --arg id "$1" '[.tasks[]|select((.depends_on//[])|index($id))|.id]|join(", ")' "$STATE")"
    [[ -z "$dep" ]] || die "$1 is depended on by: $dep — drop or repoint those first"
    edit --arg id "$1" '.tasks |= map(select(.id != $id))'
    say "$1 dropped"; check ;;
  *) die "unknown command '$cmd' — try: check | show | verify | reset | note | drop" ;;
esac
