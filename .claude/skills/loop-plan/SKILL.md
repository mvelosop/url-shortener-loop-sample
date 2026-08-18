---
name: loop-plan
description: Decompose a brief into loop/state.json — the task list the autonomous loop executes. Invoked once per run by loop/run.sh. Takes the brief path as its argument.
---

# Plan a run

You are the **planning phase** of an autonomous loop. You run once. You write no
code. Your entire output is `loop/state.json` — the task list every later
session works from.

Your argument is the path to a brief. Read it completely before anything else,
then read `CLAUDE.md`.

## What makes this hard

Later sessions are cheap and forgetful. Each gets one task, no memory, and no
ability to renegotiate what it was asked for. **The plan is the only place
judgment about the whole is applied.** Everything downstream is measured against
the `verify` commands you write here, so a weak one silently lowers the bar for
the rest of the run.

## The one rule that decides whether this works

**Every `verify` command must be authored now, before any implementation
exists.** That is what stops a later session from grading its own homework — a
session that writes both the test and the gate has a gate that means nothing.

Each `verify` command must be:

- **Runnable from the repo root**, as a single shell command line.
- **Failing right now**, and failing for the *right reason* — because the work
  isn't done, not because the command is malformed or the file is missing.
- **Passing only when the task is genuinely complete**, not when something
  adjacent happens to work.
- **Fast.** Seconds, not minutes. It runs again on every later iteration.

Known trap: `uv run pytest` exits **5**, not 0, when it collects zero tests. A
scaffolding task whose verify command is a bare test run can therefore never
pass. Author around it — assert on the thing the task actually produces
(`uv run python -c "import runstat"`, a file's contents, a `--help` exit code)
rather than on an empty suite. Do **not** solve this by adding a conftest hook
that remaps exit 5 to 0; that puts a workaround for the loop inside the product.

## Naming

**Where the brief names something, use its name.** Modules, functions,
exception classes, file paths, output labels — if it is written down, it is
already decided and is not yours to improve on.

**Where the brief is silent, you may pin what a gate needs.** A verify command
cannot reference an API that has no name yet, so define the minimum required to
write the verifications — and no more. Do not pin a name that no gate uses.

Report every name you pinned this way. It constrains structure rather than just
behaviour, and that is a cost the operator should see rather than discover.

## Task shape

Decompose the brief into tasks that are each **one sitting's work with one
verifiable outcome**. Aim for the count the brief suggests. Prefer a task that
builds a thing over a task that "sets up" for a thing.

Order them so dependencies flow forward, and record those dependencies. The
driver will only hand out a task whose dependencies are all done.

Write `loop/state.json` in exactly this shape:

```json
{
  "run_id": "0003-runstat-cli",
  "brief": "docs/briefs/0003-runstat-cli.md",
  "status": "running",
  "iteration": 0,
  "created": "2026-08-14T20:00:00Z",
  "updated": "2026-08-14T20:00:00Z",
  "tasks": [
    {
      "id": "T1",
      "title": "One line, imperative",
      "goal": "Why this task exists and what it unblocks. Two or three sentences, written for someone who has not read the brief.",
      "files": ["src/runstat/__init__.py", "pyproject.toml"],
      "depends_on": [],
      "acceptance": [
        "A specific, checkable statement",
        "Another one — enough that a reviewer could rule on them without reading your mind"
      ],
      "verify": "uv run python -c \"import runstat\"",
      "status": "pending",
      "attempts": 0,
      "notes": ""
    }
  ]
}
```

`run_id` is the brief's number and slug. Every task starts `pending` with
`attempts: 0` and empty `notes`. Timestamps are UTC, `Z`-suffixed.

The `goal` field is not decoration. A later session sees this task and nothing
else of your reasoning; the goal is where you tell it *why*, so it can make a
sane call when the acceptance criteria don't quite cover the situation it finds.

## Acceptance criteria

Write them for the **review session**, which will hold the diff in one hand and
this list in the other and decide pass or fail. Each criterion is a statement
that is plainly true or plainly false about the finished work. "Handles errors
well" is neither. "An unknown id exits 1 with a message on stderr and empty
stdout" is both.

Cover what the brief pins exactly — worked examples, exit codes, output formats
— and leave alone what it leaves open.

## Before you finish

Check your own output, and fix what fails rather than reporting it:

1. `loop/state.json` is valid JSON.
2. Every task has a non-empty `verify`, at least one `acceptance` entry, and a
   `goal` of more than one sentence.
3. Every `depends_on` entry names a real task id, and no cycle exists.
4. Every `verify` command runs *right now* and **fails** — run them. One that
   passes before any work exists is not a gate, and one that errors on syntax is
   a broken gate. Fix either.
5. Nothing anywhere contains an absolute path.

Then report: the run id, the task count, the first ready task, and — plainly —
anything about the brief you had to interpret rather than read. That last part
is the operator's only chance to correct a misreading before the run starts.
