# url-shortener

A small HTTP API that turns a long URL into a short slug, redirects on that
slug, and reports how many times it has been followed. NestJS, TypeScript,
SQLite.

## Requirements

Node 24, npm. No Docker, no external services, no network access at runtime
or in tests.

## Install

```
npm install
```

## Build

```
npm run build
```

Compiles `src/` to `dist/`, including `dist/main.js`.

## Migrate

```
DATABASE_PATH=data/links.db npm run migrate
```

Creates the SQLite file at `DATABASE_PATH` (default `data/links.db`,
repo-relative) and the `links` table, including any missing parent directory.
This is an explicit step, not run automatically on boot — running it again
against the same file is safe and leaves the schema intact.

## Start

```
PORT=3000 DATABASE_PATH=data/links.db node dist/main.js
```

Starts the built artifact. `PORT` defaults to `3000`, `DATABASE_PATH`
defaults to `data/links.db`. The database must already have been migrated.
The process shuts down cleanly on `SIGTERM`.

Once running:

- `GET /health` — `200 { "status": "ok" }`
- `POST /links` — `{ "url": "https://…" }` → `201` with the created link
- `GET /:slug` — `302` redirect to the target URL, counts a hit
- `GET /links/:slug` — `200` with the link and its hit count
- `GET /api` — browsable Swagger UI
- `GET /api-json` — the OpenAPI document

## Test

```
npm test
```

Runs the unit suite (`src/**/*.spec.ts`).

```
npm run test:e2e
```

Runs the end-to-end suite (`test/*.e2e-spec.ts`) against a throwaway SQLite
database, over HTTP with supertest. Separate command from `npm test`; no
manual setup needed.
