# The loop — a user manual

End to end: brief in, working code out, with evidence of how it got there.

For the design *rationale*, read
[brief 0002](briefs/0002-next-generation-autonomous-loop.md). This is the
operating manual.

---

## 1. The mental model

Three kinds of session, each a **fresh `claude -p` with no memory of any
other**. Files are the entire continuity.

```
brief ──▶ PLAN ──▶ state.json ──▶ ┌─ pick next ready task
 (opus, once)                     │  WORK   does one task, proposes an outcome
                                  │  GATE   driver re-runs EVERY done task's verify
                                  │  REVIEW separate, read-only, independent verdict
                                  │  driver applies it, journals, commits
                                  └─ repeat
```

The one thing to internalise: **the driver decides everything mechanical.**
Which task is next, whether a task is really done, how many attempts it has
burned, when to stop. Agents do work and give opinions. They never set status
and never commit. If you are wondering "could a session have faked this?", the
answer is almost always no, because it has no way to express the claim.

## Sessions, not subagents

Claude Code has a subagent mechanism — `.claude/agents/`, spawned with the Task
tool from inside a running session. **This loop deliberately does not use it.**
There is no `.claude/agents/` directory here. Each phase is a separate
`claude -p` process, started by a bash driver, reading a skill.

```
subagents                          this loop
─────────                          ─────────
one session                        one OS process per phase
  ├─ Task(implementer)             driver ──▶ claude -p /loop-work   (exits)
  ├─ Task(reviewer)                driver ──▶ gate                   (no model)
  └─ decides what to do next       driver ──▶ claude -p /loop-review (exits)
context accumulates                driver decides what to do next
an LLM orchestrates                a shell script orchestrates
```

### Why

**No shared memory, by construction.** A subagent's parent accumulates every
subagent's output and frames the next prompt. Here the work session and the
review session are separate processes that cannot see each other — the reviewer
physically cannot inherit the implementer's rationalisation. Isolation is a
property of the operating system, not of prompt discipline.

**The orchestrator is deterministic.** Task selection, gates, attempt counting,
stop conditions and halting are bash. That is why there are 25 checks that run free and offline with a stubbed `claude` on `PATH` — including ones for the
attempt ceiling, the convergence halt and the stale-handoff guard. **You cannot
stub the Task tool.** Every mechanical bug found in this loop was found by those
tests, not by a run.

**Per-phase telemetry falls out for free.** `claude -p --output-format json`
returns cost, turns, duration and permission denials per session, which is the
entire basis for the run-level signals. Subagent accounting rolls up into the
parent.

**Structural honesty.** A session has no way to set task status or commit — the
driver owns both. A subagent returns text to a parent that then decides, so
"the implementer marked it done" becomes a thing you must guard against.
`exploring-claude` needs a fabrication check and a verdict-guard script (in
that repo, not this one) for exactly that; here it is unrepresentable.

### What it costs

**Money and latency — but less than you would think.** Measured across run 1's
22 sessions:

| | tokens |
| --- | --- |
| read from cache | 11,335,654 |
| written to cache | 766,121 |
| **fresh (uncached) input** | **32,292** |

**93% of input is served from cache**, and uncached input averages ~20 tokens
*per session*. A genuinely cold start would pay thousands for the system prompt
and tool definitions alone, so the shared prefix is plainly not being re-bought
each time — prompt caching is content-addressed server-side, and separate
processes with the same prefix hit it.

What a fresh session does not inherit is the **conversation**. It re-reads the
files it needs and re-derives its understanding, which shows up as the ~35k of
cache *creation* per session plus its output tokens. So the real cost of the
fresh-session design is re-deriving context, not re-uploading it.

Measured all-in: ~$1 per iteration, ~$0.50 of it the work session. Subagents
would still be cheaper per step by sharing the parent's *conversation*, but the
gap is much narrower than the architecture suggests.

**It runs outside Claude.** You start it from a terminal, not from a
conversation. There is no mid-run steering, and it cannot ship as a single
plugin (see *Using the loop in another repo*).

**No cross-phase judgement.** Nothing weighs "the reviewer keeps raising the
same thing" — because nothing is holding both. That is deliberate; the run-level
signals exist to replace it, and `exploring-claude`'s own design notes record
that per-tick judgement is exactly what fails to notice a globally stuck run.

### When the other choice is right

If the work is short enough that context accumulation is a feature rather than a
liability, subagents are simpler and cheaper — one session, no driver, no
install. The fresh-session bet only pays off when a run is long enough that you
would not *want* iteration 11 to remember iteration 1.

## 2. Installing it

```bash
loop/install.sh /path/to/target-repo
```

The loop is **vendored**, not linked — there is no clean submodule or plugin
route, because it is two things with different homes: the skills must sit at
`.claude/skills/` for Claude Code to resolve `/loop-work T3`, and the driver is
a shell script you run from your terminal.

The installer handles three classes of file differently:

| | |
| --- | --- |
| **loop-owned** — `loop/`, `.claude/skills/loop-*` | overwritten; these *are* the loop |
| **shared** — `.claude/settings.json`, `CLAUDE.md` | **merged**, never clobbered |
| **yours** — everything else | never touched |

It stamps `loop/.installed` with the source commit, and finishes by **running
the loop's own suite in the target** — 25 checks, free and offline, no model.
That is the install test: a copied artefact that can prove it works where it
landed.

Re-run it to update; it is idempotent.

**Two things are yours to set**, and they are the whole stack-specific surface
(measured: ~1% of the loop's 1,170 lines):

1. `.claude/settings.json` — add the commands your gates need
   (`Bash(pnpm:*)`, `Bash(go:*)`, `Bash(cargo:*)`…). The loop never names a
   test runner: each task carries its own verify command, so **the gate list
   belongs to your plan, not to the loop**.
2. `CLAUDE.md` — the loop's rules land between `loop:begin`/`loop:end` markers.
   Add a toolchain note of your own.

Verified end to end on a Go repo with no Python present: 25 checks pass, and a
re-install over a customised consumer preserved their allow/deny entries, their
`env` block, and their own `CLAUDE.md` content.

## 3. One-time setup

**In this repo**, everything is already in place. **In any other repo**, install
it first — see the previous section — then come back here.

```bash
jq --version && git --version && claude --version   # required
```

`uv` is only needed if *your* gates use it. The loop never names a test runner.

**Trust the workspace.** Run `claude` interactively in the repo once and accept
the trust dialog. Without it `claude -p` *silently ignores* `.claude/settings.json`,
so a run executes under the wrong permission surface. Preflight refuses to start
until this is done — it is the single most common way to waste a run.

## 4. Writing a brief

The brief is the highest-leverage artefact in the system. Everything downstream
is measured against gates the planner writes *from it*.

**Pin decisions, leave mechanics open.** Name the behaviour, the exit codes, the
output format, the worked example. Do not name the module layout — that is the
implementation's to choose, and pinning it buys nothing.

**Include a worked example with exact expected values.** It becomes the
end-to-end acceptance test, and it is the arbiter when two implementations
disagree.

**Write an out-of-scope list.** It is not decoration: it is how scope creep
becomes a measurable finding rather than a matter of taste.

**Say roughly how many tasks you expect.** It calibrates decomposition.

Start from the template, which is a filled-in skeleton of the shape below:

```bash
cp loop/brief-template.md docs/briefs/0001-my-thing.md
```

Check it before you spend anything:

```bash
loop/check-brief.sh docs/briefs/0001-your-brief.md
```

It verifies the structure a brief needs: a worked example with concrete values,
a non-empty out-of-scope list, constraints, an expected task count, pinned exit
or status codes, no absolute paths, and that every path it references resolves.
Briefs are only checked if they say `**Status:** ready to plan` — a discussion
document is not a worse brief, it is a different kind of document.

**It cannot check the thing that matters most**, which is whether the brief pins
decisions and leaves mechanics open. A brief can pass every check and still be
bad. That judgement is what the list above is for.

See [brief 0003](briefs/0003-runstat-cli.md) (greenfield) and
[brief 0004](briefs/0004-runstat-review.md) (incremental) as worked examples.

## 5. Planning, and checking the plan before you spend

```bash
LOOP_MAX_ITERATIONS=0 loop/run.sh docs/briefs/000N-....md
```

Runs the plan phase alone and stops at the budget (exit 4, resumable). ~$2–4.
**Do this on anything unfamiliar.** The plan authors every `verify` command, and
a weak one silently lowers the bar for the whole run.

Then read `loop/plan.md` and the top of the plan's journal. The planner's report
ends with **what it interpreted rather than read** — that list is your one cheap
chance to catch a misreading before every iteration inherits it.

### Amending the plan

The plan is yours **between** runs and the driver's **during** one. Use
`loop/amend.sh` rather than editing JSON blind — every operation validates and
re-renders, so a mistake surfaces now instead of several minutes into the run:

```bash
loop/amend.sh show                       # the plan, or `show T4` for one task
loop/amend.sh verify T4 'uv run pytest -q tests/test_x.py'
loop/amend.sh reset  T4                  # back to pending, attempts 0
loop/amend.sh note   T4 'the fixture moved to tests/data'
loop/amend.sh drop   T4                  # refuses if anything depends on it
loop/amend.sh check                      # after ANY hand-edit
```

`check` is the important one. It verifies the schema, that every task has a gate
and criteria, that dependencies resolve and contain no cycle, that no ids are
duplicated — and it **runs every pending task's gate to warn you about any that
already pass**, because a gate that is green before the work exists proves
nothing.

Hand-editing `loop/state.json` is still fine — it is only JSON — but run
`loop/amend.sh check` afterwards.

Anything structural (re-scoping, adding tasks) is better done by editing the
brief and re-planning than by patching state.

Continue with no state edit:

```bash
loop/run.sh
```

## 6. Running

```bash
loop/run.sh docs/briefs/000N-....md   # plan, then iterate
loop/run.sh                           # resume
```

Budgets are **per-run** and checked **between iterations**, so raising one and
re-running always works with no state edit. Defaults: 30 iterations, $40,
3 attempts per task, halt above 3.0 iterations-per-closed-task.

| Variable | Default |
| --- | --- |
| `LOOP_MAX_ITERATIONS` · `LOOP_COST_CEILING` | 30 · 40 |
| `LOOP_MAX_ATTEMPTS` · `LOOP_STALL_LIMIT` | 3 · 2 |
| `LOOP_CONVERGENCE_MAX` · `LOOP_CONVERGENCE_MIN` | 3.0 · 6 |
| `LOOP_PLAN_MODEL` · `LOOP_WORK_MODEL` | opus · sonnet |
| `LOOP_ARCHIVE_TRANSCRIPTS` | 0 |

Expect **~$1 per iteration** on a greenfield plan. Incremental work inverts the
profile — planning was 42% of run 3's cost, because the planner must read
existing code before it can write gates against it.

## 7. Watching it

**In the terminal you started it in.** The driver prints a block after every
iteration:

```
iterations · tasks closed · iterations per closed · gate failures
review rejections · attempts burned · no-progress streak · estimated spend
```

**If you backgrounded it** — and you probably should, since a run takes tens of
minutes — the same output is on disk. The run announces its own path in the
preflight block (`telemetry dir loop/runs/<branch>/<timestamp>`):

```bash
tail -f loop/runs/<branch>/<timestamp>/loop.log     # follow it live
ls -dt loop/runs/*/*/ | head -1                     # the newest run
```

**Between runs**, `loop/plan.md` and the plan's journal are re-rendered after
every iteration, so they are current even mid-run — and they read better on a
phone than a log does.

**Healthy is `iterations per closed` near 1.0.** Climbing means re-work; above
3.0 (after 6 iterations) the run halts itself. These exist because every other
mechanism judges a tick against its task, and nothing else judges the run
against the point of the run.

## 8. When it stops

| Status | Exit | What to do |
| --- | --- | --- |
| complete | 0 | read the journal, open a PR |
| preflight failed | 1 | fix what it named — it names one thing |
| blocked | 2 | a task burned its attempts; read its `notes` in `state.json` |
| stalled | 3 | two iterations with no recorded progress; read the run dir |
| max iterations | 4 | raise `LOOP_MAX_ITERATIONS`, re-run |
| not converging | 5 | **stop and look** — the run is going nowhere |
| cost ceiling | 6 | raise `LOOP_COST_CEILING`, re-run |
| session error | 7 | a `claude` session died; see the run dir |

Complete, max-iterations, stalled and cost-ceiling resume by just re-running.
Blocked, not-converging and session-error want a human first.

## 9. Reading what happened

| | |
| --- | --- |
| `loop/plan.md` | **where are we** — every task, status, attempts, criteria, gate |
| `loop/journals/<plan-id>.md` | **what happened** — planner's report,one entry per iteration, outcome and signals |
| `runstat summary <run-dir>` | per-phase cost, turns, wall time; flags errors and permission denials |
| `runstat signals <run-dir>` | the eight run-level signals |
| `runstat review <run-dir>` | what the reviews ruled, their findings, and coherence checks |
| `runstat compare <a> <b>` | two runs side by side |

Run dirs are `loop/runs/<branch>/<timestamp>/`.

## 10. Running several loops at once

**One loop per git worktree.**

```bash
git worktree add ../loop-006 006-some-plan
cd ../loop-006 && loop/run.sh docs/briefs/0006-....md
```

Git refuses to check one branch out twice, so separate worktrees are necessarily
separate branches. Two loops in **one** working tree share `loop/proposal.json`,
so one's review could pass a task on the other's evidence — the driver takes a
lock (`loop/.running`) and refuses.

## 11. Merging

Branches are **squash-merged and never deleted** — they hold the per-iteration
commits, which are the evidence each task was done by a separate fresh session.

`loop/state.json` belongs to the branch. Merging main *into* a branch must
preserve the branch's copy; main's copy is meaningless. This is deliberately not
mechanised — see `loop/README.md` for why `merge=ours` is a trap — so resolve by
hand:

```bash
git checkout --ours loop/state.json && loop/render-plan.sh
git add loop/state.json loop/plan.md
```

A branch that inherits foreign state resets it when you pass a brief, and
refuses when you do not. **The brief, not the branch, decides.**

## 12. Changing the loop itself

```bash
loop/tests/run-all.sh                                     # free, offline, always
loop/tests/reviewer-calibration/run-calibration.sh        # ~$1.20, calls a model
```

**Run the suite before and after any change to `loop/run.sh`.** And when you add
a test, prove it can fail — break the thing deliberately and watch it go red.
Three tests in this repo have looked green while testing nothing, each asserting
something true in both the good and the bad case.

Changing `.claude/skills/loop-review/SKILL.md`? Re-run the calibration and
compare against [the baseline](../loop/tests/reviewer-calibration/RESULTS.md).
A review contract that stops catching planted defects has regressed, whatever
its prose says.

## 13. Troubleshooting

| Symptom | Cause |
| --- | --- |
| Preflight: "workspace NOT trusted" | §2. Silently voids all permission rules. |
| "a loop is already running in this working tree" | Two loops, one tree. Use a worktree, or clear a stale `loop/.running`. |
| "state.json holds plan X for '\<other brief\>'" | The branch inherited another plan. Passing your brief resets it. |
| "belongs to branch … no way to tell" | Ambiguous with no brief. Pass one. |
| A scaffolding task can never pass | `uv run pytest` exits **5**, not 0, on zero tests collected. Gate on the artefact, not an empty suite. |
| Run halts "not converging" | Re-work loop. Read the failing task's `notes` — it is usually one gate that cannot be satisfied as written. |
