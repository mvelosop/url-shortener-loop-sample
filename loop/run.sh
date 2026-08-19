#!/usr/bin/env bash
#
# The autonomous loop driver.
#
#   loop/run.sh [brief-path]
#
# Plans once from a brief, then repeats: pick the next ready task, run a work
# session on it, gate every completed task, run an independent review session,
# apply the verdict, commit. Every session is a fresh `claude -p` with no memory
# of any other; all continuity lives in files under loop/.
#
# The driver owns every mechanical decision — which task is next, whether a task
# is really done, how many attempts it has burned, whether the run is
# converging, and when to stop. Agents do the work and give opinions; they never
# set status and never commit.
#
# Design: docs/briefs/0002-next-generation-autonomous-loop.md
#
# Exit codes
#   0  plan complete            4  max iterations (resumable)
#   1  preflight / usage        5  not converging  (needs a human)
#   2  blocked (needs a human)  6  cost ceiling    (resumable)
#   3  stalled                  7  session error   (needs a human)
#
# Env
#   LOOP_MAX_ITERATIONS   iterations this run may use          (default 30)
#   LOOP_COST_CEILING     dollars this run may spend           (default 40)
#   LOOP_MAX_ATTEMPTS     failures before a task is blocked    (default 3)
#   LOOP_STALL_LIMIT      no-change iterations before stopping (default 2)
#   LOOP_CONVERGENCE_MAX  max iterations-per-closed-task       (default 3.0)
#   LOOP_CONVERGENCE_MIN  iterations before that check arms    (default 6)
#   LOOP_PLAN_MODEL       model for the plan phase             (default opus)
#   LOOP_WORK_MODEL       model for work + review              (default sonnet)
#   LOOP_ARCHIVE_TRANSCRIPTS=1   copy session transcripts out of ~/.claude
#   LOOP_TRANSCRIPT_DIR   where to put them  (default ../loop-transcripts)

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

LOOP_DIR="$REPO/loop"
STATE="$LOOP_DIR/state.json"
PROPOSAL="$LOOP_DIR/proposal.json"
VERDICT="$LOOP_DIR/verdict.json"

MAX_ITER="${LOOP_MAX_ITERATIONS:-30}"
COST_CEILING="${LOOP_COST_CEILING:-40}"
MAX_ATTEMPTS="${LOOP_MAX_ATTEMPTS:-3}"
STALL_LIMIT="${LOOP_STALL_LIMIT:-2}"
CONVERGENCE_MAX="${LOOP_CONVERGENCE_MAX:-3.0}"
CONVERGENCE_MIN="${LOOP_CONVERGENCE_MIN:-6}"
PLAN_MODEL="${LOOP_PLAN_MODEL:-opus}"
WORK_MODEL="${LOOP_WORK_MODEL:-sonnet}"

BRIEF="${1:-}"
BRANCH="$(git branch --show-current 2>/dev/null)"
[[ -n "$BRANCH" ]] || BRANCH="detached-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
BRANCH_SAFE="${BRANCH//\//-}"
# Grouped by branch, so two loops running in parallel write to different paths.
# Within one branch the timestamp is only second-resolution, and two runs can
# land in the same second — a quick preflight failure followed by a re-run, or
# a test firing several in a row. A collision would have the later run truncate
# the earlier one's telemetry, so make the directory unique rather than assume.
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_ID="$RUN_STAMP"
_n=1
while [[ -d "$LOOP_DIR/runs/$BRANCH_SAFE/$RUN_ID" ]]; do
  _n=$((_n + 1)); RUN_ID="$RUN_STAMP-$_n"
done
RUN_PATH="$BRANCH_SAFE/$RUN_ID"
RUN_DIR="$LOOP_DIR/runs/$RUN_PATH"
SESSIONS="$RUN_DIR/sessions"
ITERATIONS="$RUN_DIR/iterations.jsonl"

SESSION_N=0

# ---------------------------------------------------------------- helpers ---

# Hard rule 2's backstop. Agents are told to write repo-relative paths; tool
# output and stack traces are not under their control, so everything this script
# persists goes through here.
USER_NAME="$(basename "$HOME")"
mask() { sed -e "s#${HOME}#~#g" -e "s#${USER_NAME}#USER#g"; }

# Everything the driver persists goes through mask() — including its own log,
# which is committed as evidence. An absolute path reaching a message is a
# mistake waiting to happen, so the backstop sits here rather than at each
# call site.
say()  { printf '\033[36m[loop]\033[0m %s\n' "$(printf '%s' "$*" | mask)" | tee -a "$RUN_DIR/loop.log" >&2; }
warn() { printf '\033[33m[loop]\033[0m %s\n' "$(printf '%s' "$*" | mask)" | tee -a "$RUN_DIR/loop.log" >&2; }
die()  { printf '\033[31m[loop] %s\033[0m\n' "$(printf '%s' "$*" | mask)" >&2; exit 1; }
ts()   { date -u +%Y-%m-%dT%H:%M:%SZ; }

# All state access goes through jq. Never grep/sed/awk over the state file — a
# hand-rolled parser meeting a document format is where this class of loop
# reliably breaks (docs/references/executable-loop-harness.md).
state_get() { jq -r "$@" "$STATE"; }

# Atomic: build the new state beside the old one, then rename over it. A run
# killed mid-write leaves the previous state intact rather than a truncated file.
state_edit() {
  local tmp
  tmp="$(mktemp "$LOOP_DIR/.state.XXXXXX")"
  if jq "$@" "$STATE" >"$tmp"; then
    mv "$tmp" "$STATE"
  else
    rm -f "$tmp"
    die "state edit failed: $*"
  fi
}

# state.json is what the driver computes over; plan.md is what a human reads.
# Rendered after every state change, one direction only, never parsed back.
render_plan() {
  "$LOOP_DIR/render-plan.sh" "$STATE" "$LOOP_DIR/plan.md" \
    || warn "plan render failed — loop/plan.md may be stale"
}

# One `claude -p` session, fully contained: project settings only, no MCP
# servers, no memory of anything else. Its result JSON is stamped with the phase
# and iteration that produced it, masked, and kept as telemetry.
run_session() {
  local phase="$1" iter="$2" model="$3" prompt="$4" rc=0 raw out
  SESSION_N=$((SESSION_N + 1))
  out="$(printf '%s/%03d-%s.json' "$SESSIONS" "$SESSION_N" "$phase")"
  raw="$out.raw"

  claude -p "$prompt" \
    --model "$model" \
    --permission-mode auto \
    --setting-sources project \
    --strict-mcp-config \
    --output-format json \
    >"$raw" 2>"$RUN_DIR/$phase-$iter.stderr"
  rc=$?

  if [[ -s "$raw" ]]; then
    jq --arg p "$phase" --argjson i "$iter" '. + {phase: $p, iteration: $i}' "$raw" \
      | mask >"$out" 2>/dev/null || cp "$raw" "$out"
  fi
  rm -f "$raw"

  if [[ -s "$out" ]]; then
    jq -r '"    cost=$\(.total_cost_usd // 0) turns=\(.num_turns // 0) dur=\(((.duration_ms // 0)/1000)|round)s error=\(.is_error // false)"' \
      "$out" 2>/dev/null | while read -r l; do say "$l"; done
    local denials
    denials="$(jq -r '.permission_denials | length' "$out" 2>/dev/null || echo 0)"
    [[ "${denials:-0}" -gt 0 ]] && warn "    $denials permission denial(s) — the fence may be in the wrong place"
  fi

  archive_transcript "$out" "$phase" "$iter"
  return $rc
}

# Session transcripts live in ~/.claude and are collected after ~30 days. They
# hold absolute paths and full file contents, so this is off unless asked for,
# and it never writes inside the repo.
archive_transcript() {
  [[ "${LOOP_ARCHIVE_TRANSCRIPTS:-0}" == "1" ]] || return 0
  local result="$1" phase="$2" iter="$3" sid src dest
  dest="${LOOP_TRANSCRIPT_DIR:-$REPO/../loop-transcripts}/$RUN_PATH"
  case "$(cd "$dest" 2>/dev/null && pwd)" in "$REPO"|"$REPO"/*)
    warn "refusing to archive transcripts inside the repo"; return 0 ;;
  esac
  sid="$(jq -r '.session_id // empty' "$result" 2>/dev/null)" || return 0
  [[ -n "$sid" ]] || return 0
  src="$(find "$HOME/.claude/projects" -maxdepth 2 -name "$sid.jsonl" -print -quit 2>/dev/null)"
  [[ -n "$src" ]] || return 0
  mkdir -p "$dest" && cp "$src" "$dest/$(printf '%03d-%s-iter%s.jsonl' "$SESSION_N" "$phase" "$iter")"
}

# ------------------------------------------------------------------ gates ---

# Re-run the verify command of every task named. This is the whole point of the
# external gate: "done" has to survive a command the session neither runs nor can
# edit. Echoes the ids that failed.
gate_ids() {
  local id cmd rc failed=()
  mkdir -p "$RUN_DIR/gates"
  for id in "$@"; do
    cmd="$(state_get --arg id "$id" '.tasks[]|select(.id==$id)|.verify')"
    [[ -n "$cmd" && "$cmd" != "null" ]] || continue
    rc=0
    bash -c "$cmd" >"$RUN_DIR/gates/$id.log.raw" 2>&1 || rc=$?
    mask <"$RUN_DIR/gates/$id.log.raw" >"$RUN_DIR/gates/$id.log"
    rm -f "$RUN_DIR/gates/$id.log.raw"
    [[ $rc -ne 0 ]] && failed+=("$id")
  done
  printf '%s\n' "${failed[@]:-}"
}

# --------------------------------------------------------------- signals ----
#
# The run-level view. Every gate can be green and every review thorough while
# the run goes nowhere, because each of those judges a tick against its task and
# nothing judges the run against the point of the run
# (docs/references/executable-loop-harness.md Rule 7). These are the numbers
# that make that visible from outside, and one of them can stop the run.
#
# runstat recomputes all of this in Python afterwards; brief 0002 acceptance
# item 6 requires the two to agree. If you change a formula here, change it
# there — the fixture in brief 0003 is the arbiter.

sig_iterations()  { [[ -f "$ITERATIONS" ]] && wc -l <"$ITERATIONS" | tr -d ' ' || echo 0; }
# `jq -s` on an unmatched glob BOTH prints 0 and exits non-zero, so a bare
# `jq ... || echo 0` emits "0\n0" — which awk then rejects, silently disabling
# the cost-ceiling comparison. Check the glob matched instead of relying on ||.
sig_spend() {
  local f=("$SESSIONS"/*.json)
  [[ -e "${f[0]}" ]] || { echo 0; return 0; }
  jq -s '[.[] | .total_cost_usd // 0] | add // 0' "${f[@]}" 2>/dev/null || echo 0
}
sig_closed()      { jq -s 'if length == 0 then 0 else (.[-1].tasks_done // 0) end' "$ITERATIONS" 2>/dev/null || echo 0; }
sig_total()       { jq -s 'if length == 0 then 0 else (.[-1].tasks_total // 0) end' "$ITERATIONS" 2>/dev/null || echo 0; }
sig_gate_fails()  { jq -s '[.[]|select(.outcome=="gate_fail")]|length' "$ITERATIONS" 2>/dev/null || echo 0; }
sig_review_fails(){ jq -s '[.[]|select(.outcome=="review_fail")]|length' "$ITERATIONS" 2>/dev/null || echo 0; }
# Iterations that did not close their task. NOT the sum of `.attempts` — that
# field is a cumulative per-task counter, so summing it double-counts a task
# that appears in more than one record.
sig_attempts()    { jq -s '[.[]|select(.outcome!="done")]|length' "$ITERATIONS" 2>/dev/null || echo 0; }

sig_per_closed() {
  local i c; i="$(sig_iterations)"; c="$(sig_closed)"
  if [[ "${c:-0}" -eq 0 ]]; then echo "n/a"; else
    awk -v i="$i" -v c="$c" 'BEGIN{printf "%.2f", i/c}'
  fi
}

# Trailing iterations that closed nothing.
sig_streak() {
  jq -s '[.[] | .tasks_done // 0] as $d
         | ([0] + $d[:-1]) as $p
         | [range(0; ($d|length))] | map(if $d[.] > $p[.] then 1 else 0 end)
         | (reverse | index(1)) // length' "$ITERATIONS" 2>/dev/null || echo 0
}

print_signals() {
  say "  ── signals ──"
  say "  iterations:            $(sig_iterations)"
  say "  tasks closed:          $(sig_closed)/$(sig_total)"
  say "  iterations per closed: $(sig_per_closed)"
  say "  gate failures:         $(sig_gate_fails)"
  say "  review rejections:     $(sig_review_fails)"
  say "  attempts burned:       $(sig_attempts)"
  say "  no-progress streak:    $(sig_streak)"
  say "  estimated spend:       \$$(printf '%.2f' "$(sig_spend)") (estimate, not a bill)"
}

# --------------------------------------------------------------- lock -------
#
# Parallel loops are supported, one per git WORKTREE. Git already guarantees
# those are on different branches — it refuses to check one branch out twice —
# so the only thing left to prevent is two loops in the SAME working tree,
# where they would share loop/state.json and, far worse, loop/proposal.json:
# one loop's review session reading the other loop's proposal is exactly the
# stale-handoff failure the driver clears per-iteration to avoid.
#
# A lock that can brick the loop is worse than no lock, so it records a pid and
# a dead one is cleared rather than obeyed.
LOCK="$LOOP_DIR/.running"

acquire_lock() {
  if [[ -f "$LOCK" ]]; then
    local pid other started
    pid="$(jq -r '.pid // ""' "$LOCK" 2>/dev/null)"
    other="$(jq -r '.branch // "?"' "$LOCK" 2>/dev/null)"
    started="$(jq -r '.started // "?"' "$LOCK" 2>/dev/null)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      die "a loop is already running in this working tree.
  pid $pid · branch '$other' · started $started
  Two loops in one tree share loop/state.json and loop/proposal.json, so one
  can mark a task done on the other's evidence. To run in parallel, give each
  its own worktree:
    git worktree add ../<dir> <branch>"
    fi
    warn "clearing a stale lock (pid ${pid:-unknown} is gone)"
  fi
  jq -nc --arg p "$$" --arg b "$BRANCH" --arg t "$(ts)" --arg r "$RUN_PATH" \
    '{pid: $p, branch: $b, started: $t, run: $r}' >"$LOCK"
  trap 'rm -f "$LOCK"' EXIT
}

# ------------------------------------------------------------- preflight ----

preflight() {
  local ok=1
  say "preflight"

  for t in jq claude git; do
    if command -v "$t" >/dev/null 2>&1; then say "  [x] $t"
    else say "  [ ] $t — missing"; ok=0; fi
  done
  command -v uv >/dev/null 2>&1 && say "  [x] uv" || warn "  [ ] uv — missing (the demo target needs it)"

  # An untrusted workspace makes `claude -p` silently ignore this repo's
  # settings.json permissions. That failure took out a whole prior experiment
  # and left one line in a log preamble as its only trace. Fail loudly.
  local trusted
  trusted="$(jq -r --arg p "$REPO" '.projects[$p].hasTrustDialogAccepted // false' "$HOME/.claude.json" 2>/dev/null)"
  if [[ "$trusted" == "true" ]]; then
    say "  [x] workspace trusted"
  else
    say "  [ ] workspace NOT trusted — settings.json permissions would be silently ignored"
    say "      fix: run \`claude\` interactively here once and accept the trust dialog"
    ok=0
  fi

  if jq -e . .claude/settings.json >/dev/null 2>&1; then
    say "  [x] settings.json parses — $(jq '.permissions.allow|length' .claude/settings.json) allow, $(jq '.permissions.deny|length' .claude/settings.json) deny rules"
  else
    say "  [ ] .claude/settings.json missing or invalid"; ok=0
  fi

  # The driver makes one commit per iteration. A repo with no identity
  # configured fails at the END of iteration 1, after both sessions have been
  # paid for: the most expensive place to find a one-line setup problem.
  if git config user.email >/dev/null 2>&1 && git config user.name >/dev/null 2>&1; then
    say "  [x] git identity ($(git config user.email))"
  else
    say "  [ ] git user.name/user.email not set - the first commit would fail"
    say "      fix: git config user.email you@example.com && git config user.name 'Your Name'"
    ok=0
  fi

  # A hook that rejects the driver's commit fails in the same place. We cannot
  # know whether it would pass, only that it is there to be considered.
  hookdir="$(git config core.hooksPath 2>/dev/null || echo .git/hooks)"
  if [[ -x "$hookdir/pre-commit" ]]; then
    warn "  [!] a pre-commit hook is active ($hookdir/pre-commit)"
    warn "      if it rejects the driver's commit, the run stops after paying for a task"
  fi

  [[ -n "$HOME" && -n "$USER_NAME" ]] \
    && say "  [x] masking active (\$HOME and username)" \
    || { say "  [ ] masking cannot resolve \$HOME"; ok=0; }

  mkdir -p "$SESSIONS" 2>/dev/null \
    && say "  [x] telemetry dir loop/runs/$RUN_PATH" \
    || { say "  [ ] cannot create telemetry dir"; ok=0; }

  if [[ -f "$STATE" ]]; then
    if jq -e . "$STATE" >/dev/null 2>&1; then say "  [x] state.json valid — $(state_get '[.tasks[]|select(.status=="pending")]|length') pending"
    else say "  [ ] state.json is not valid JSON"; ok=0; fi
  else
    say "  [x] no state — will plan first"
  fi

  [[ $ok -eq 1 ]] || die "preflight failed — nothing has run"
  say "preflight ok"
}

# ------------------------------------------------------------------- run ----

mkdir -p "$SESSIONS"
acquire_lock
: >"$RUN_DIR/loop.log"
: >"$ITERATIONS"
preflight

# --- plan phase (once) ---

# The journal is named for the PLAN, so a resumed run keeps appending to the
# same narrative while a different plan — on this branch or a parallel one —
# never touches this file.
open_journal() {
  JOURNAL="$LOOP_DIR/journals/$(state_get .run_id).md"
  mkdir -p "$LOOP_DIR/journals"
  [[ -f "$JOURNAL" ]] || printf '# Journal — %s\n\nAppend-only narrative of this plan. Rendered state lives in loop/plan.md.\n' \
    "$(state_get .run_id)" >"$JOURNAL"
}

# A branch cut from main inherits whatever state.json the last squash left
# there — another branch's plan. It must never be resumed as if it were this
# branch's work.
#
# The discriminator is the BRIEF, not the branch. A branch name cannot tell an
# inherited plan from your own plan on a branch you renamed, and guessing wrong
# in the destructive direction loses a run. The brief names which plan you are
# asking for, so it answers the question directly.
if [[ -f "$STATE" ]]; then
  STATE_BRIEF="$(state_get '.brief // ""')"
  STATE_BRANCH="$(state_get '.branch // ""')"
  if [[ -n "$BRIEF" ]]; then
    if [[ -n "$STATE_BRIEF" && "$STATE_BRIEF" != "$BRIEF" ]]; then
      say "state.json holds plan $(state_get .run_id) for '$STATE_BRIEF'"
      say "  you asked for '$BRIEF' — resetting and planning fresh"
      rm -f "$STATE" "$LOOP_DIR/plan.md"
    fi
    # Same brief: this is the plan you asked for. Resume it whatever branch it
    # was stamped on — that is how a renamed branch recovers, without the
    # operator having to reach for the one flag that would destroy the run.
  elif [[ -n "$STATE_BRANCH" && "$STATE_BRANCH" != "$BRANCH" ]]; then
    die "state.json holds plan $(state_get .run_id), stamped on branch '$STATE_BRANCH'; you are on '$BRANCH'.
  With no brief there is no way to tell an inherited plan from your own on a
  renamed branch, and the two want opposite things. Say which you mean:
    resume it            loop/run.sh $STATE_BRIEF
    start a new plan     loop/run.sh docs/briefs/<other>.md"
  fi
fi

if [[ ! -f "$STATE" ]]; then
  if [[ -z "$BRIEF" ]]; then
    BRIEF="$(ls -1 docs/briefs/*.md 2>/dev/null | tail -1)"
    [[ -n "$BRIEF" ]] || die "no state and no brief. usage: loop/run.sh docs/briefs/NNNN-slug.md"
  fi
  [[ -f "$BRIEF" ]] || die "brief not found: $BRIEF"

  say "planning from $BRIEF using $PLAN_MODEL"
  run_session plan 0 "$PLAN_MODEL" "/loop-plan $BRIEF" \
    || die "planning session failed — see loop/runs/$RUN_PATH/"

  [[ -f "$STATE" ]] || die "planning produced no loop/state.json"
  jq -e . "$STATE" >/dev/null 2>&1 || die "loop/state.json is not valid JSON"

  # The plan skill is told to check its own work; this is the driver checking it
  # anyway, because a plan that cannot be validated is a planning failure and
  # every downstream session would inherit it.
  n_bad="$(state_get '[.tasks[]|select((.verify//"")=="" or ((.acceptance//[])|length)==0)]|length')"
  [[ "$n_bad" -eq 0 ]] || die "$n_bad task(s) have no verify command or no acceptance criteria — fix the plan"
  bad_dep="$(state_get '[.tasks[].id] as $ids | [.tasks[]|.depends_on[]?|select(($ids|index(.))==null)] | length')"
  [[ "$bad_dep" -eq 0 ]] || die "$bad_dep dependency reference(s) name a task that does not exist"

  # The driver stamps both, rather than trusting the plan session to record
  # them: which branch and which brief a plan belongs to are facts the driver
  # already holds, and the brief is now what decides whether a later run
  # resumes this plan or resets it.
  state_edit --arg b "$BRANCH" --arg f "$BRIEF" '.branch = $b | .brief = $f'
  say "planned: $(state_get '"\(.run_id) — \(.tasks|length) tasks"')"
  open_journal

  # The plan phase's report carries the planner's "what I interpreted rather
  # than read" list — the operator's one cheap chance to catch a misreading
  # before every iteration inherits it. It is otherwise reachable only as a
  # long string inside a session JSON blob, which nobody reads on a phone.
  {
    printf '\n## Plan — %s\n\n' "$(state_get .run_id)"
    printf -- '- **Brief:** `%s`\n' "$BRIEF"
    printf -- '- **Tasks:** %s\n\n' "$(state_get '.tasks|length')"
    jq -r '.result // ""' "$SESSIONS"/*-plan.json 2>/dev/null | mask
    printf '\n'
  } >>"$JOURNAL"

  render_plan
  git add -A && git commit -q -m "[loop] plan $(state_get .run_id)" && say "committed the plan"
else
  say "resuming $(state_get .run_id) — $(state_get '[.tasks[]|select(.status=="done")]|length')/$(state_get '.tasks|length') done"
  state_edit --arg t "$(ts)" --arg b "$BRANCH" '.status="running" | .updated=$t | .branch=$b'
  open_journal
fi

# --- iterate ---

run_iters=0
stalls=0
status="max_iterations"
exit_code=4

while true; do
  pending="$(state_get '[.tasks[]|select(.status=="pending")]|length')"
  blocked="$(state_get '[.tasks[]|select(.status=="blocked")]|length')"
  done_n="$(state_get '[.tasks[]|select(.status=="done")]|length')"
  total="$(state_get '.tasks|length')"

  if [[ "$pending" -eq 0 ]]; then
    if [[ "$blocked" -gt 0 ]]; then status="blocked"; exit_code=2
    else status="complete"; exit_code=0; fi
    break
  fi

  # Budgets are checked here, between iterations — never mid-iteration. A run
  # always stops with state coherent, so raising a limit and re-running just
  # works. They are per-run, not per-plan: a runaway backstop, not a
  # convergence detector. That job belongs to the signal below.
  if [[ "$run_iters" -ge "$MAX_ITER" ]]; then status="max_iterations"; exit_code=4; break; fi

  spend="$(sig_spend)"
  if awk -v s="$spend" -v c="$COST_CEILING" 'BEGIN{exit !(s>=c)}'; then
    status="cost_ceiling"; exit_code=6; break
  fi

  iters="$(sig_iterations)"
  if [[ "${iters:-0}" -ge "$CONVERGENCE_MIN" ]]; then
    pc="$(sig_per_closed)"
    if [[ "$pc" == "n/a" ]] || awk -v p="$pc" -v m="$CONVERGENCE_MAX" 'BEGIN{exit !(p>m)}'; then
      status="not_converging"; exit_code=5; break
    fi
  fi

  # Next ready task: first pending task whose dependencies are all done. The
  # driver picks it; the work session is told which one and does not choose.
  task="$(state_get '[.tasks[]|select(.status=="done")|.id] as $d
                     | [.tasks[]|select(.status=="pending")
                        | select(([.depends_on[]?|select(($d|index(.))==null)]|length)==0)][0].id // empty')"
  if [[ -z "$task" ]]; then
    warn "$pending task(s) pending but none are ready — dependencies cannot be satisfied"
    status="blocked"; exit_code=2; break
  fi

  run_iters=$((run_iters + 1))
  iter="$(( $(state_get .iteration) + 1 ))"
  say "── iteration $iter ($run_iters/$MAX_ITER this run) · $task · $done_n/$total done ──"
  say "   $(state_get --arg id "$task" '.tasks[]|select(.id==$id)|.title')"

  # A stale file from a previous iteration must never be mistaken for this
  # iteration's report.
  rm -f "$PROPOSAL" "$VERDICT"

  # 1. work session
  run_session work "$iter" "$WORK_MODEL" "/loop-work $task"
  if [[ $? -ne 0 && ! -f "$PROPOSAL" ]]; then
    status="session_error"; exit_code=7; break
  fi

  if [[ ! -f "$PROPOSAL" ]] || ! jq -e . "$PROPOSAL" >/dev/null 2>&1; then
    warn "work session left no valid proposal"
    outcome="blocked"; summary="work session produced no proposal"; notes="none"
  else
    outcome="$(jq -r '.outcome // "blocked"' "$PROPOSAL")"
    summary="$(jq -r '.summary // ""' "$PROPOSAL" | mask)"
    notes="$(jq -r '.notes // "none"' "$PROPOSAL" | mask)"
  fi

  # 2. gate — every done task, plus this one if it claims to be done
  gate_targets=()
  while read -r id; do [[ -n "$id" ]] && gate_targets+=("$id"); done \
    < <(state_get '.tasks[]|select(.status=="done")|.id')
  [[ "$outcome" == "done" ]] && gate_targets+=("$task")

  gate_failed=()
  if [[ ${#gate_targets[@]} -gt 0 ]]; then
    while read -r id; do [[ -n "$id" ]] && gate_failed+=("$id"); done \
      < <(gate_ids "${gate_targets[@]}")
  fi

  # Gate logs are keyed by task id and overwritten every iteration, so a failing
  # log would be erased by the next passing run of the same task — losing the
  # only record of the failure. Keep a per-iteration copy of the failures.
  for id in "${gate_failed[@]:-}"; do
    [[ -n "$id" ]] || continue
    cp "$RUN_DIR/gates/$id.log" "$RUN_DIR/gates/$(printf '%03d' "$iter")-$id.fail.log" 2>/dev/null
  done

  # A previously-done task that no longer verifies is a regression: revert it,
  # charge it an attempt. This is the check that per-task gates alone cannot do.
  for id in "${gate_failed[@]:-}"; do
    [[ -n "$id" && "$id" != "$task" ]] || continue
    warn "   GATE REGRESSION $id — reverting to pending"
    state_edit --arg id "$id" --arg n "regressed: verify failed during $task — see loop/runs/$RUN_PATH/gates/$id.log" \
      '(.tasks[]|select(.id==$id)) |= (.status="pending" | .attempts=(.attempts+1) | .notes=$n)'
  done

  candidate_failed=0
  for id in "${gate_failed[@]:-}"; do [[ "$id" == "$task" ]] && candidate_failed=1; done

  verdict="skipped"
  if [[ "$outcome" == "blocked" ]]; then
    say "   work session reported blocked"
  elif [[ $candidate_failed -eq 1 ]]; then
    outcome="gate_fail"
    warn "   GATE FAIL $task — review skipped, work that fails its own gate is not reviewable"
  else
    # 3. review session — separate, read-only, sees the diff and not the summary
    run_session review "$iter" "$WORK_MODEL" "/loop-review $task"
    if [[ ! -f "$VERDICT" ]] || ! jq -e . "$VERDICT" >/dev/null 2>&1; then
      warn "   review session left no valid verdict — treating as FAIL"
      verdict="FAIL"
    else
      verdict="$(jq -r '.verdict // "FAIL"' "$VERDICT")"
    fi
    [[ "$verdict" == "PASS" ]] || outcome="review_fail"
    say "   review: $verdict"
  fi

  # 4. apply — the driver makes every status transition
  case "$outcome" in
    done)
      state_edit --arg id "$task" '(.tasks[]|select(.id==$id)) |= (.status="done" | .notes="")'
      say "   $task done" ;;
    gate_fail|review_fail)
      reason="$([[ "$outcome" == "gate_fail" ]] \
        && echo "gate failed — see loop/runs/$RUN_PATH/gates/$task.log" \
        || jq -r '(.findings // []) | join("; ")' "$VERDICT" 2>/dev/null | mask)"
      state_edit --arg id "$task" --arg n "$reason" \
        '(.tasks[]|select(.id==$id)) |= (.status="pending" | .attempts=(.attempts+1) | .notes=$n)' ;;
    blocked)
      state_edit --arg id "$task" --arg n "$summary" \
        '(.tasks[]|select(.id==$id)) |= (.status="pending" | .attempts=(.attempts+1) | .notes=$n)' ;;
  esac

  # A task that has burned its attempts is blocked, not retried forever.
  n_new="$(state_get --argjson m "$MAX_ATTEMPTS" '[.tasks[]|select(.status=="pending" and .attempts>=$m)]|length')"
  if [[ "$n_new" -gt 0 ]]; then
    state_edit --argjson m "$MAX_ATTEMPTS" '(.tasks[]|select(.status=="pending" and .attempts>=$m)) |= (.status="blocked")'
    warn "   $n_new task(s) hit the attempt ceiling — blocked"
  fi

  state_edit --arg t "$(ts)" --argjson i "$iter" '.iteration=$i | .updated=$t'

  # 5. record — telemetry, journal, evidence
  new_done="$(state_get '[.tasks[]|select(.status=="done")]|length')"
  jq -nc --argjson i "$iter" --arg t "$task" --arg o "$outcome" \
     --argjson a "$(state_get --arg id "$task" '.tasks[]|select(.id==$id)|.attempts')" \
     --argjson d "$new_done" --argjson n "$total" \
     '{iteration:$i, task:$t, outcome:$o, attempts:$a, tasks_done:$d, tasks_total:$n}' >>"$ITERATIONS"

  mkdir -p "$RUN_DIR/reports"
  [[ -f "$PROPOSAL" ]] && mask <"$PROPOSAL" >"$RUN_DIR/reports/$(printf '%03d' "$iter")-proposal.json"
  [[ -f "$VERDICT" ]]  && mask <"$VERDICT"  >"$RUN_DIR/reports/$(printf '%03d' "$iter")-verdict.json"

  # The journal's prose is the sessions'; assembling it is the driver's, so the
  # entry always carries the verdict and always passes through the mask.
  {
    printf '\n## %s — %s\n\n' "$task" "$(state_get --arg id "$task" '.tasks[]|select(.id==$id)|.title')"
    printf -- '- **Outcome:** %s (review: %s)\n' "$outcome" "$verdict"
    printf -- '- **Summary:** %s\n' "${summary:-none}"
    printf -- '- **Files:** %s\n' "$(jq -r '(.files // []) | join(", ")' "$PROPOSAL" 2>/dev/null | mask || echo none)"
    printf -- '- **Notes for next iteration:** %s\n' "${notes:-none}"
  } >>"$JOURNAL"

  render_plan

  # 6. commit — one per iteration, driver-owned, covering code + state +
  # journal + telemetry together. Agents never commit, so the history is a
  # record of what the loop decided rather than of what a session claimed.
  git add -A >/dev/null 2>&1
  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -q -m "[loop] $task: $outcome" && say "   committed $(git rev-parse --short HEAD)"
  fi

  print_signals

  # Stall detection: an iteration that closed nothing and burned no attempt has
  # made no recorded progress at all.
  if [[ "$new_done" -le "$done_n" && "$outcome" != "gate_fail" && "$outcome" != "review_fail" ]]; then
    stalls=$((stalls + 1))
    warn "   no recorded progress ($stalls/$STALL_LIMIT)"
    if [[ "$stalls" -ge "$STALL_LIMIT" ]]; then status="stalled"; exit_code=3; break; fi
  else
    stalls=0
  fi
done

# --- report ---

state_edit --arg s "$status" --arg t "$(ts)" '.status=$s | .updated=$t'

say ""
say "═══ $status ═══"
say "run:    $RUN_PATH  ($run_iters iteration(s) this run)"
say "plan:   $(state_get '[.tasks[]|select(.status=="done")]|length')/$(state_get '.tasks|length') done, $(state_get '[.tasks[]|select(.status=="blocked")]|length') blocked"
print_signals
say ""
say "per-phase cost:"
for p in plan work review; do
  jq -s --arg p "$p" '[.[]|select(.phase==$p)] | "  \($p): \(length) session(s), $\([.[].total_cost_usd//0]|add//0|.*100|round/100), \([.[].num_turns//0]|add//0) turns"' \
    "$SESSIONS"/*.json 2>/dev/null | tr -d '"' | while read -r l; do say "$l"; done
done
say ""
case "$status" in
  complete)       say "plan complete. journal: ${JOURNAL#$REPO/}" ;;
  blocked)        say "a human is needed. read the blocked task's notes in loop/state.json" ;;
  stalled)        say "no recorded progress twice running — read loop/runs/$RUN_PATH/" ;;
  max_iterations) say "iteration budget spent. resumable: re-run loop/run.sh" ;;
  cost_ceiling)   say "cost ceiling reached. resumable: raise LOOP_COST_CEILING and re-run" ;;
  not_converging) say "iterations-per-closed-task exceeded $CONVERGENCE_MAX — the run is not converging." ;;
  session_error)  say "a claude session failed. see loop/runs/$RUN_PATH/" ;;
esac
render_plan

# Every session writes a stderr file; almost all are empty, and committing 36
# empty files per run buries the ones that are not. A non-empty stderr is the
# evidence you want when a session dies, so keep those and drop the rest.
find "$RUN_DIR" -name '*.stderr' -empty -delete 2>/dev/null

{
  printf '\n## Run ended — %s\n\n' "$status"
  printf -- '- **Run:** `%s` · %s iteration(s) this run\n' "$RUN_ID" "$run_iters"
  printf -- '- **Plan:** %s/%s done, %s blocked\n' \
    "$(state_get '[.tasks[]|select(.status=="done")]|length')" \
    "$(state_get '.tasks|length')" \
    "$(state_get '[.tasks[]|select(.status=="blocked")]|length')"
  printf -- '- **Signals:** %s iterations · %s per closed · %s gate failure(s) · %s review rejection(s) · %s attempt(s) burned · streak %s · ~$%s\n' \
    "$(sig_iterations)" "$(sig_per_closed)" "$(sig_gate_fails)" "$(sig_review_fails)" \
    "$(sig_attempts)" "$(sig_streak)" "$(printf '%.2f' "$(sig_spend)")"
} >>"$JOURNAL"

git add -A >/dev/null 2>&1
git diff --cached --quiet 2>/dev/null || git commit -q -m "[loop] run $RUN_PATH: $status"

exit "$exit_code"
