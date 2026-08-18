# Reviewer calibration — baseline

**2026-08-18 · sonnet · 4/4 caught · ~$1.31**

Two full runs of the loop produced 21 work/review pairs and **zero** rejections
(27 across three runs now). That is either a reviewer with nothing to catch or
a reviewer that cannot catch, and no number of clean runs tells the two apart.
This plants the defect instead of waiting for one.

Every case passes its own gate before the reviewer sees it — enforced by the
harness, because a case whose gate fails measures the gate, not the review.

| Case | Planted defect | Verdict |
| --- | --- | --- |
| `01-hollow-test` | tests run and assert nothing that could fail | **FAIL** |
| `02-hardcoded-fixture` | `compute_signals` ignores its argument, returns the fixture's answers | **FAIL** |
| `03-scope-creep` | correct command, plus a `--json` flag the brief excludes | **FAIL** |
| `04-unchecked-criterion` | error printed to stdout as well as stderr; no test asserts it | **FAIL** |

## Reading the results

Verdicts are written **run-shaped**, so the same tool reads a calibration and a
real run:

```bash
runstat review loop/tests/reviewer-calibration/results/<timestamp>
runstat signals loop/tests/reviewer-calibration/results/<timestamp>
```

Which makes the contrast one command instead of two tools:

|  | real work (run 1) | planted defects |
| --- | --- | --- |
| reviews | 11 | 4 |
| failed | 0 | 4 |
| findings | 0 | 11 |
| criteria ruled | 68 | 16 |
| criteria not met | 0 | 11 |

`tasks closed` reads `0/4` on a perfect calibration: a caught defect is work the
review *rejected*, so nothing closes. `review rejections: 4` is the score.

## What it establishes

**Does:** a real review session rejects gate-passing work that violates its
acceptance criteria, including the two shapes a gate structurally cannot see —
work that is correct but out of scope, and criteria no test asserts. It names
the defect specifically rather than finding something else and getting lucky,
citing the brief by line number and reading the diff against `HEAD` to spot a
deleted implementation.

**Does not:** that it catches *subtle* defects. These were planted, and a
deliberately hollow test is easier than a plausible one that happens to be
inadequate. One model, one contract version.

**Reproducibility:** two independent runs both scored 4/4, with finding *counts*
varying (14 then 11). The verdicts are stable; the volume of prose is not.

Re-run after any change to `.claude/skills/loop-review/SKILL.md` and compare.
A review contract that stops catching planted defects has regressed, whatever
its prose says.
