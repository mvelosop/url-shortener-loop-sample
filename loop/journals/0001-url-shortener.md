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


## Run ended — max_iterations

- **Run:** `20260818-221720` · 0 iteration(s) this run
- **Plan:** 0/10 done, 0 blocked
- **Signals:** 0 iterations · n/a per closed · 0 gate failure(s) · 0 review rejection(s) · 0 attempt(s) burned · streak 0 · ~$3.95

## T1 — Scaffold the NestJS project with a working build, two test commands and GET /health

- **Outcome:** done (review: PASS)
- **Summary:** Scaffolded the NestJS + TypeScript project: package.json, tsconfig(.build).json, nest-cli.json, src/main.ts, src/app.module.ts, a health slice (controller + spec) answering GET /health, and a separate jest-e2e config for test/*.e2e-spec.ts.
- **Files:** package.json, tsconfig.json, tsconfig.build.json, nest-cli.json, src/main.ts, src/app.module.ts, src/health/health.controller.ts, src/health/health.controller.spec.ts, test/jest-e2e.json, .gitignore
- **Notes for next iteration:** package.json omits a `migrate` script on purpose — T2 owns src/database/migrate.ts and should add the script when it adds the file; adding it now would reference a nonexistent script, which is why the T1 gate's `try{migrate(db)}catch(e){}` swallows the failure. `npm run test:e2e` exists and is wired to test/jest-e2e.json with supertest installed, but currently exits 1 with 'No tests found' since no *.e2e-spec.ts file exists yet (that's T9) — this is expected and matches the brief's warning not to gate scaffolding on an empty suite; T1's own gate never invokes test:e2e. Used @nestjs/core ^10.4.15 (Nest 10, not 11) since it's the stable line paired with @nestjs/cli ^10.4.9; nothing in the brief pins a major version.

## T2 — Create the links schema with an explicit npm run migrate step

- **Outcome:** done (review: PASS)
- **Summary:** Added the SQLite connection (DATABASE_PATH, default data/links.db) and an explicit `npm run migrate` script that creates the links table (slug primary key, url, hits, created_at); the app boots against it without ever creating the schema itself.
- **Files:** package.json, src/database/database.module.ts, src/database/migrate.ts, src/app.module.ts
- **Notes for next iteration:** Used Node 24's built-in node:sqlite (DatabaseSync) directly, no ORM — avoids native module builds under the no-network constraint, and the gate itself already assumes node:sqlite is available since it uses it to inspect the schema. migrate.ts exports `migrate()` and only calls it when run as the entrypoint (`require.main === module`); database.module.ts imports the same DEFAULT_DATABASE_PATH constant from migrate.ts, which is safe because importing the module does not trigger the migration (that import is what makes 'no synchronise-on-boot' hold). Both migrate.ts and the DatabaseModule factory create the DATABASE_PATH's parent directory (mkdirSync recursive) before opening the file — required because node:sqlite's DatabaseSync throws if the parent directory doesn't exist, but this is directory creation only, never schema creation, so the unmigrated-boot gate still sees no links table. The DATABASE_CONNECTION provider is exported from a @Global() DatabaseModule for T3+ to inject; nothing reads or writes rows yet. package.json's migrate script runs the built dist/database/migrate.js (npm run build already compiles src/database/migrate.ts alongside the rest via nest-cli's default src->dist mapping).

## T3 — Create a link with POST /links

- **Outcome:** done (review: PASS)
- **Summary:** Added POST /links: a links module/controller/service/repository that generates a random 6-character [A-Za-z0-9] slug, writes a row to the links table via node:sqlite, and returns {slug, url, hits, createdAt} with no de-duplication.
- **Files:** src/links/links.module.ts, src/links/links.controller.ts, src/links/links.service.ts, src/links/links.repository.ts, src/links/dto/create-link.dto.ts, src/app.module.ts
- **Notes for next iteration:** Slug generation is a free function (generateSlug) inlined in links.service.ts using node:crypto randomBytes, not yet behind an injectable/seedable provider — that refactor into src/links/slug.generator.ts is T7's job (it also owns the collision-retry loop); T3 only needed a well-formed slug. CreateLinkDto is a plain class with no validation decorators (T6 adds those plus a global ValidationPipe in main.ts); a malformed body will currently pass through un-validated. LinksRepository.create() builds the returned LinkRecord in JS from the same slug/url/createdAt it inserts rather than reading the row back, so hits comes back as the number 0 (not whatever type sqlite would give it) and createdAt is exactly the ISO string passed in. DB column is created_at (snake_case, from T2's migration) but the repository/service/response use createdAt (camelCase) — intentional mapping, not an inconsistency.

## T4 — Redirect on GET /:slug, counting hits, and read a link with GET /links/:slug

- **Outcome:** done (review: PASS)
- **Summary:** Added GET /:slug (redirect, increments hits) via a new RedirectController, and GET /links/:slug (pure read) on the existing LinksController; the repository gained findBySlug and incrementHits.
- **Files:** src/links/links.controller.ts, src/links/redirect.controller.ts, src/links/links.service.ts, src/links/links.repository.ts, src/links/links.module.ts
- **Notes for next iteration:** RedirectController (@Controller() with @Get(':slug') + @Redirect()) is registered in LinksModule's controllers array after LinksController: [LinksController, RedirectController]. Empirically this puts the catch-all :slug route after /health (declared directly on AppModule, which is imported after LinksModule in the module graph) and after /links/:slug (registered earlier in the same array) in Nest's route table, so GET /health and GET /links/:slug are matched first and never reach the redirect handler; verified by booting the built artifact and hitting /health, /links/:slug and /:slug directly, plus the gate's own health-after-redirect check. LinksService.redirect()/findBySlug() both throw NestJS's built-in NotFoundException when the repository returns undefined — this is necessary just to avoid the redirect/read handlers crashing on an unknown slug (an UPDATE on a non-existent slug is a harmless no-op, then the follow-up SELECT returns undefined), not an attempt to fully implement T5's 404 acceptance criteria (JSON message body, no-DB-row-created checks, etc. are exercised by T5's own gate, which I did not run).

## T5 — Return 404 for an unknown slug on both lookup routes

- **Outcome:** done (review: PASS)
- **Summary:** No code changes were needed: T4's LinksService.findBySlug/redirect already throw NestJS's built-in NotFoundException on a missing slug, which both LinksController (GET /links/:slug) and RedirectController (GET /:slug) surface as a 404 JSON body before any redirect or DB write happens.
- **Files:** 
- **Notes for next iteration:** T4 already implemented everything T5's acceptance criteria ask for (its own journal entry says as much but notes the T5 gate was never run). RedirectController's handler is decorated with @Redirect(), but NestJS's exception filters run before the redirect/response pipeline, so a thrown NotFoundException short-circuits cleanly to a 404 with no Location header — verified directly with curl, not just inferred. incrementHits() in links.repository.ts does an UPDATE ... WHERE slug = ? followed by a SELECT; on an unknown slug the UPDATE is a no-op (0 rows affected) and the SELECT returns undefined, so no row is ever created — confirmed via the verify script's post-run `select count(*) from links` check (== 1, only the link created during setup). npm run test:e2e still reports 'No tests found' with exit 1, unchanged from T1/T4 — that's T9's file to add, not touched here.

## T6 — Reject an invalid url with 400 naming the offending field

- **Outcome:** done (review: PASS)
- **Summary:** POST /links now validates the url field with class-validator decorators and a global ValidationPipe, returning 400 for missing/null/empty/non-string/non-http(s) urls while still accepting valid http:// and https:// urls.
- **Files:** src/links/dto/create-link.dto.ts, src/main.ts, package.json, package-lock.json
- **Notes for next iteration:** Installed class-validator and class-transformer (not previously in package.json) since NestJS's ValidationPipe needs them; ran `npm install class-validator class-transformer --save`. CreateLinkDto now has @IsString/@IsNotEmpty/@IsUrl({protocols:['http','https'], require_protocol:true}) on url; class-validator validates undefined/null values against these decorators by default (no @IsOptional used), so a missing url field is rejected the same as an invalid one. main.ts adds `app.useGlobalPipes(new ValidationPipe({whitelist:true, transform:true}))` — this is the only place validation is wired, so it only takes effect for requests that go through the real Nest HTTP bootstrap (dist/main.js or a full app.listen()); an e2e test that builds a Nest testing module without replicating this pipe would not get validation. Left the default class-validator error messages as-is (e.g. 'url must be a URL address') since they already name the field, satisfying the gate's /url/i check on the response body; did not write a custom exceptionFactory.

## T7 — Guarantee unique slugs: seedable generation, collision retry, 500 only after five

- **Outcome:** done (review: PASS)
- **Summary:** Slug generation now sits behind an injectable SlugGenerator provider (deterministic when SLUG_SEED is set, random otherwise); LinksService retries up to 5 candidates on a collision and throws a 500 only after all 5 are exhausted, writing no row.
- **Files:** src/links/slug.generator.ts, src/links/slug.generator.spec.ts, src/links/links.service.ts, src/links/links.service.spec.ts, src/links/links.module.ts, src/links/links.repository.ts
- **Notes for next iteration:** RandomSlugGenerator (src/links/slug.generator.ts) uses a mulberry32 PRNG seeded by hashing SLUG_SEED when it's set, and node:crypto randomBytes per-call when it's unset — the seeded path is what gate/tests use to force real collisions across process restarts, since a fresh process with the same seed replays the same slug sequence from position 1. LinksRepository gained tryCreate(), which catches node:sqlite's collision error (error.code === 'ERR_SQLITE_ERROR' with message 'UNIQUE constraint failed: ...') and returns null instead of throwing, so LinksService.create() can loop up to MAX_SLUG_ATTEMPTS=5 candidates and only throw InternalServerErrorException (500) after the 5th failure; the original create() (throwing) is kept as-is and reused by tryCreate() to avoid duplicating the INSERT. links.module.ts provides SLUG_GENERATOR via a factory reading process.env.SLUG_SEED at module-instantiation time (once per process boot), matching the brief's 'injectable or seedable' requirement with both. links.service.spec.ts uses a small in-file QueueSlugGenerator fake plus a fake repository (no real sqlite) to force the retry-then-succeed and exhaust-then-500 paths deterministically without booting the app.
