# Brief 0001 — a URL shortener API

- **Status:** ready to plan
- **Built by:** the autonomous loop (`loop/README.md`, `docs/manual.md`)
- **Starting point:** greenfield. This repo contains the loop, this brief, and
nothing else. Scaffolding the project is the first task.

---

## What it is

A small HTTP API that turns a long URL into a short slug, redirects on that
slug, and reports how many times it has been followed. NestJS, TypeScript,
SQLite. API only — no web pages, but a browsable Swagger UI.

## Why this target

The loop has so far built command-line programs, where "prove the artifact
runs" means running a command that exits. A long-running HTTP server with a
health endpoint is the one case its design notes single out as the hardest to
generalise, and the one an adapter written against a single stack gets wrong.
So the point of this brief is not the domain. **The domain is deliberately
small so that the stack is what gets exercised**: a built artifact that must
boot and stay up, two tiers of test that are different commands, and a
framework whose generators invite work nobody asked for.

---

## The API

| | | |
| --- | --- | --- |
| `POST /links` | `{ "url": "https://…" }` | `201` with the created link |
| `GET /:slug` | | `302` to the target URL, and the hit count increases |
| `GET /links/:slug` | | `200` with the link and its hit count |
| `GET /health` | | `200 { "status": "ok" }` |
| `GET /api` | | Swagger UI, browsable |
| `GET /api-json` | | the OpenAPI document |

A link is:

```json
{ "slug": "aB3xK9", "url": "https://example.com/a/long/path", "hits": 0,
  "createdAt": "2026-08-18T21:00:00.000Z" }
```

## Behaviour contract

**Slugs** are exactly 6 characters from `[A-Za-z0-9]`, generated, and unique.

**A slug collision must never reach the client.** On collision the service
retries with a new slug; only after several consecutive collisions does it fail,
and then with `500`, never with a duplicate.

> **This has to be testable, which constrains the design.** Slug generation must
> be injectable or seedable so a test can *force* a collision deterministically.
> A collision-retry path that cannot be exercised is a claim, not a behaviour.

**Hits** increase on `GET /:slug` only. Reading `GET /links/:slug` never changes
the count.

**Status codes.** `201` on create. `302` on redirect, with the target in
`Location`. `404` for an unknown slug on both `GET /:slug` and
`GET /links/:slug`. `400` for a missing, empty, non-string or non-HTTP(S) `url`.
Validation errors name the offending field.

**The same URL submitted twice produces two independent links** with different
slugs. There is no de-duplication.

**Persistence is real.** Links survive a process restart. The schema is created
by a migration or an equivalent explicit step, not by an implicit "synchronise
on boot" that would silently mask a broken schema.

**No network at runtime.** The service never fetches the target URL, does not
validate that it resolves, and has no outbound calls at all.

## Swagger

`GET /api` serves a browsable UI. `GET /api-json` serves an OpenAPI document
that lists all four functional paths and describes the request body and the
success response for `POST /links`. The document is generated from the code, not
hand-written, so it cannot drift.

---

## Worked example

The end-to-end acceptance test. Note that slugs are generated, so **the test
must thread the slug it received** rather than hardcoding one — an
implementation that only works for a fixed slug should fail this.

```
POST /links  { "url": "https://example.com/a/very/long/path" }
  -> 201, body.slug matches ^[A-Za-z0-9]{6}$, body.hits == 0
     body.url == the submitted url

GET /links/{slug}
  -> 200, hits == 0

GET /{slug}
  -> 302, Location == "https://example.com/a/very/long/path"

GET /{slug}                       (again)
  -> 302

GET /links/{slug}
  -> 200, hits == 2               (redirects counted, this read did not)

GET /nope99
  -> 404

GET /links/nope99
  -> 404

POST /links  { "url": "not-a-url" }
  -> 400

POST /links  { "url": "https://example.com/a/very/long/path" }   (same url)
  -> 201, slug differs from the first
```

## Proving it runs

**One task must gate on the built artifact actually starting**, not on an
in-process test. Build it, start `dist/main.js` as a background process against
a real SQLite file, wait for it to come up, call `/health` and `/api-json` over
HTTP, then stop it. A non-zero exit, a boot failure, or a missing endpoint fails
the gate.

This is deliberate. Most of the behaviour above can be gated with supertest
without ever binding a port, which is faster and more reliable — and would also
let a broken build pass every test. The boot check is the one that would notice.

## Out of scope

Not smaller versions of these. Not at all:

- custom or vanity slugs
- expiry, TTL, or deletion
- any analytics beyond the single hit counter
- authentication, API keys, rate limiting
- a web UI of any kind, beyond the Swagger page
- QR codes, bulk import, redirect chains
- Docker, docker-compose, or any external service

## Constraints

- NestJS with TypeScript. SQLite on disk. The ORM or query layer is the
  implementation's choice.
- Node 24, npm. No Docker. No network access at runtime or during tests.
- Unit tests and end-to-end tests are separate commands, and both must pass.
- The full suite runs in seconds, so every gate stays cheap enough to re-run on
  every iteration.
- Repo-relative paths everywhere. No absolute paths in any file, log, or commit
  message.

## Shape

Nine to eleven tasks. The scaffolding is the first of them, and it is real work:
a NestJS project, a test runner that will run, supertest wired up, and a
`/health` endpoint that responds.

Gate the scaffolding on something the project produces, not on an empty test
run. **A test runner given no tests does not reliably exit 0**, so a first task
whose gate is a bare suite run either fails for the wrong reason or has to be
told to tolerate emptiness, which then tolerates it forever. Assert on the build
output, on `/health`, and on one real test that genuinely runs.
