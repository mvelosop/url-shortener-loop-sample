# Journal — 0001-url-shortener

Append-only narrative of this plan. Rendered state lives in loop/plan.md.

## Plan — 0001-url-shortener

- **Brief:** `docs/briefs/0001-url-shortener.md`
- **Tasks:** 10

Plan written and validated. Scratch dirs in `$TMPDIR` (`planwork`, `gatecheck`) survive — the cleanup was denied; nothing in the repo touched them.

## Run

**`0001-url-shortener`** — 10 tasks, `loop/state.json` + rendered `loop/plan.md`. `loop/amend.sh check` passes.

**First ready task: T1** — scaffold the NestJS project (build, two test commands, `GET /health`). It's the only task with no dependencies.

The chain is T1 → T2 → T3, then T4/T6/T7 fan out from T3, T5 and T8 from T4, T9 gathers T5+T6+T7, and T10 closes on T8+T9.

## How I checked the gates

All ten run from the repo root and **fail today** — `npm error code ENOENT`, no package.json yet, which is failure for the right reason. (I dropped `--silent` from the build step after finding it swallowed npm's error entirely, leaving a gate that failed with zero diagnostic.)

Failing now isn't enough, though — a gate that fails on everything is no better than one that passes on everything. So I also ran all ten against a throwaway stub outside the repo: a fake `dist/main.js` serving only `/health`, plus a real migration script and a fake test reporter. T1 and T2 pass there (the stub genuinely satisfies them); the other eight fail at the exact assertion they should — `POST /links returned 404, expected 201`, `GET /api returned 404, expected a browsable Swagger UI`. That run caught a weak gate: **T5 originally passed against a stub that 404s everything.** It now creates a link first and proves the known slug still redirects, so a blanket 404 fails it.

## What I interpreted rather than read

The gates are Node probes that build, boot `dist/main.js` on ports 3101–3110 against throwaway SQLite files, and assert over HTTP. Writing them before any code exists meant pinning names the brief leaves open:

- **`SLUG_SEED` is the significant one.** The brief asks for slug generation that is "injectable *or* seedable"; I require both. Injectable alone can only be forced from inside a test the work session writes — the gate would be reading that session's homework. `SLUG_SEED` makes the sequence reproducible per process, so the gate forces a real collision from outside: create links with a seed, restart with the same seed, and the candidates collide for real. T7 also checks the seed genuinely reproduces, so the collision can't be faked by randomness.
- **"Several consecutive collisions" → exactly 5 candidates per create, then 500.** The gate needs a number. Two collisions must still return 201; five must return 500 with no row written.
- **`npm run migrate`, `DATABASE_PATH` (default `data/links.db`), `PORT`** — the gate has to stand up a database and a port.
- **Jest**, because the gates parse `--json --outputFile` reports. This follows `nest new`, but it does rule out swapping runners.
- **Table `links`** with `slug`/`url`/`hits` and a created-at column (I accept either `created_at` or `createdAt`, leaving the ORM choice open); slug must be the primary key or uniquely indexed.
- **`createdAt` is ISO-8601 UTC with milliseconds** — read off the brief's worked example, but the brief never says it's binding.
- **404 bodies are JSON with a `message`** (Nest's default exception shape), and **SIGTERM may exit 0 *or* terminate by SIGTERM** — Nest's shutdown hooks re-raise the signal, so demanding exit 0 would fail a correct implementation.

One gate is weaker than the rest and you should know it: **T9 can only read jest's report about the e2e suite** — no gate can confirm from outside that the suite really threads the returned slug. I required at least 4 passing tests and two consecutive clean runs (which breaks a hardcoded slug or leaked state), but the worked-example fidelity is the review session's call, so T9's acceptance criteria spell out each step.

