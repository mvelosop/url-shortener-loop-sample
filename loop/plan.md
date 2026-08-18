# Plan — 0001-url-shortener

<!-- Rendered from loop/state.json by loop/render-plan.sh.
     Do NOT edit: regenerated on every state change, your edits will be lost.
     The source of truth is loop/state.json. -->

**Status:** running · **0/10 done** · iteration 0

**Brief:** `docs/briefs/0001-url-shortener.md` · **Updated:** 2026-08-18T21:30:54Z

## Progress

- [ ] **T1** — Scaffold the NestJS project with a working build, two test commands and GET /health
- [ ] **T2** — Create the links schema with an explicit npm run migrate step
- [ ] **T3** — Create a link with POST /links
- [ ] **T4** — Redirect on GET /:slug, counting hits, and read a link with GET /links/:slug
- [ ] **T5** — Return 404 for an unknown slug on both lookup routes
- [ ] **T6** — Reject an invalid url with 400 naming the offending field
- [ ] **T7** — Guarantee unique slugs: seedable generation, collision retry, 500 only after five
- [ ] **T8** — Serve a browsable Swagger UI at /api and the OpenAPI document at /api-json
- [ ] **T9** — Write the end-to-end acceptance test for the brief's worked example
- [ ] **T10** — Prove the built artifact boots, shuts down cleanly, and keeps its links across a restart

## Tasks

### T1 — Scaffold the NestJS project with a working build, two test commands and GET /health

`pending` · depends on: none

This repo is greenfield: it holds the loop, the brief and nothing else. This task creates the NestJS + TypeScript project that every later task builds on, and fixes the two things every later gate depends on — that `npm run build` produces `dist/main.js`, and that the built artifact boots and answers `GET /health`. It also wires the two test commands (`npm test` for unit specs, `npm run test:e2e` for supertest end-to-end specs) so that later tasks have somewhere to put tests. Build only the health slice: no links controller, service or entity yet.

**Acceptance**

- `npm run build` exits 0 and produces `dist/main.js`.
- `node dist/main.js` starts, listens on the port named by the `PORT` environment variable (default 3000), and answers `GET /health` with status 200 and the JSON body {"status":"ok"}.
- The process shuts down when sent SIGTERM; it does not have to be killed.
- `npm test` runs the unit suite (jest over `src/**/*.spec.ts`), reports at least one passing test and zero failures, and does not run any `*.e2e-spec.ts` file.
- `npm run test:e2e` exists as a separate command configured by `test/jest-e2e.json`, with supertest installed and available.
- Nothing is generated beyond this slice: no links controller/service/entity, no Docker or compose files, no CI configuration, no web assets.
- `node_modules/`, `dist/` and the runtime database directory are gitignored, and no file contains an absolute path.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const db=G+"/t1.db"; try{migrate(db);}catch(e){} const p=boot(3101,{DATABASE_PATH:db}); if(!(await up(3101))){return fail("dist/main.js did not answer GET /health with 200 on port 3101 within 20s");} const r=await fetch(H+3101+"/health"); if(r.status!==200){return fail("GET /health returned "+r.status);} const b=await r.json().catch(()=>null); if(!b||b.status!=="ok"){return fail("GET /health body was "+JSON.stringify(b)+", expected {status:ok}");} const s=await stop(p); if(s.code!==0&&s.signal!=="SIGTERM"){return fail("the server exited with code "+s.code+" signal "+s.signal);} done(); })().catch(e=>fail(String((e&&e.stack)||e)));' && npm test --silent -- --json --outputFile="$d/unit.json" >/dev/null && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const u=require(G+"/unit.json"); if(u.success!==true||u.numFailedTests!==0){return fail("npm test reported "+u.numFailedTests+" failing tests");} if(u.numPassedTests<1){return fail("npm test ran "+u.numTotalTests+" tests and passed "+u.numPassedTests+"; the unit suite must contain at least one real passing test");} done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

### T2 — Create the links schema with an explicit npm run migrate step

`pending` · depends on: T1

Persistence has to be real and the schema has to come from an explicit step, because a synchronise-on-boot would silently paper over a broken schema. This task adds the SQLite connection (file path from `DATABASE_PATH`) and a `npm run migrate` script that creates the `links` table, and it is what lets every later gate stand up a throwaway database. Nothing reads or writes rows yet — that starts in T3.

**Acceptance**

- `DATABASE_PATH=<file> npm run migrate` exits 0 and creates the SQLite file, including any missing parent directory.
- The migration creates a `links` table with columns for the slug, the url, the hit count and the creation timestamp.
- The slug column is the primary key or is covered by a unique index, so the database itself refuses duplicate slugs.
- Running `npm run migrate` a second time against the same file exits 0 and leaves the schema intact.
- Booting the application against a database that has never been migrated does not create the `links` table: there is no synchronise-on-boot, and no ORM auto-sync flag is enabled.
- `DATABASE_PATH` defaults to a repo-relative path (`data/links.db`); no absolute path appears in any source or config file.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const fs=require("node:fs"); const sq=require("node:sqlite"); const db1=G+"/migrated.db"; migrate(db1); migrate(db1); if(!fs.existsSync(db1)){return fail("npm run migrate did not create the database file at DATABASE_PATH");} const h=new sq.DatabaseSync(db1); const tables=h.prepare("select name from sqlite_master where type = ?").all("table").map(r=>String(r.name).toLowerCase()); if(!tables.includes("links")){return fail("after npm run migrate there is no links table; tables were: "+tables.join(","));} const cols=h.prepare("select * from pragma_table_info(?)").all("links"); const names=cols.map(c=>String(c.name).toLowerCase()); for(const c of ["slug","url","hits"]){if(!names.includes(c)){return fail("the links table has no "+c+" column; columns were: "+names.join(","));}} if(!names.includes("created_at")&&!names.includes("createdat")){return fail("the links table has no created-at column; columns were: "+names.join(","));} const pk=cols.filter(c=>c.pk>0).map(c=>String(c.name).toLowerCase()); const uniq=[]; for(const i of h.prepare("select * from pragma_index_list(?)").all("links")){if(i["unique"]===1){const ic=h.prepare("select * from pragma_index_info(?)").all(i.name).map(x=>String(x.name).toLowerCase());if(ic.length===1){uniq.push(ic[0]);}}} if(!pk.includes("slug")&&!uniq.includes("slug")){return fail("slug is neither the primary key nor covered by a unique index, so the database cannot enforce slug uniqueness");} h.close(); const db2=G+"/unmigrated.db"; const p=boot(3102,{DATABASE_PATH:db2}); await up(3102); await new Promise(r=>setTimeout(r,1500)); await stop(p); if(fs.existsSync(db2)){const e=new sq.DatabaseSync(db2);const t2=e.prepare("select name from sqlite_master where type = ?").all("table").map(r=>String(r.name).toLowerCase());e.close();if(t2.includes("links")){return fail("booting the app created the links table in an unmigrated database; the schema must come from npm run migrate only, never from synchronise-on-boot");}} done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

### T3 — Create a link with POST /links

`pending` · depends on: T2

This is the first behaviour of the API: accept a long url and hand back a stored link with a generated slug. It establishes the link representation ({slug, url, hits, createdAt}) that every other endpoint returns, and the repository write path that T4 reads back. Slug generation only has to produce a well-formed slug here; uniqueness under collision is T7's problem, and validation of bad input is T6's.

**Acceptance**

- `POST /links` with body {"url": "https://example.com/a/very/long/path"} returns 201.
- The response body has exactly the fields slug, url, hits and createdAt.
- slug matches ^[A-Za-z0-9]{6}$, url is the submitted url unchanged, and hits is the number 0 (not the string "0").
- createdAt is an ISO-8601 UTC timestamp with milliseconds, e.g. 2026-08-18T21:00:00.000Z.
- The link is written to the `links` table in the SQLite file named by `DATABASE_PATH`, and is still there after the process exits.
- Submitting the same url twice creates two independent rows with different slugs — there is no de-duplication.
- The service never fetches or resolves the target url, and makes no outbound network call of any kind.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const sq=require("node:sqlite"); const db=G+"/t3.db"; migrate(db); const p=boot(3103,{DATABASE_PATH:db}); if(!(await up(3103))){return fail("the server did not come up on port 3103");} const r=await post(3103,{url:URL1}); if(r.status!==201){return fail("POST /links returned "+r.status+", expected 201");} const b=await r.json(); if(typeof b.slug!=="string"||!/^[A-Za-z0-9]{6}$/.test(b.slug)){return fail("slug was "+JSON.stringify(b.slug)+", expected 6 characters of [A-Za-z0-9]");} if(b.url!==URL1){return fail("url came back as "+JSON.stringify(b.url));} if(b.hits!==0){return fail("hits was "+JSON.stringify(b.hits)+", expected the number 0");} if(typeof b.createdAt!=="string"||isNaN(Date.parse(b.createdAt))){return fail("createdAt was "+JSON.stringify(b.createdAt));} if(b.createdAt!==new Date(b.createdAt).toISOString()){return fail("createdAt was "+b.createdAt+", expected ISO-8601 UTC with milliseconds");} const r2=await post(3103,{url:URL1}); if(r2.status!==201){return fail("the second POST of the same url returned "+r2.status+", expected 201");} const b2=await r2.json(); if(b2.slug===b.slug){return fail("the same url twice produced the same slug "+b.slug+"; there must be no de-duplication");} await stop(p); const h=new sq.DatabaseSync(db); const rows=h.prepare("select slug,url from links").all(); h.close(); if(rows.length!==2){return fail("expected 2 rows in the links table after two creates, found "+rows.length);} if(!rows.some(x=>x.slug===b.slug&&x.url===URL1)){return fail("the created link was not persisted to sqlite");} done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

### T4 — Redirect on GET /:slug, counting hits, and read a link with GET /links/:slug

`pending` · depends on: T3

This is what the shortener is for: following a slug redirects to the target and is the only thing that counts. Reading a link back through `GET /links/:slug` must be a pure read, which is the distinction the worked example checks (two redirects then a read reports hits == 2). The redirect route lives at the application root, so this task is also where route ordering matters — `/health`, `/links`, `/api` and `/api-json` must keep working alongside it.

**Acceptance**

- `GET /:slug` for a known slug returns 302 with the `Location` header set to exactly the stored url.
- Each `GET /:slug` increases that link's hit count by exactly one, and the increase is persisted.
- `GET /links/:slug` returns 200 with slug, url, hits and createdAt for a known slug.
- `GET /links/:slug` never changes the hit count, however many times it is called.
- After two redirects and any number of reads, `GET /links/:slug` reports hits == 2.
- `GET /health` still returns 200: the root `:slug` route does not shadow the fixed routes.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const db=G+"/t4.db"; migrate(db); const p=boot(3104,{DATABASE_PATH:db}); if(!(await up(3104))){return fail("the server did not come up on port 3104");} const c=await post(3104,{url:URL1}); if(c.status!==201){return fail("POST /links returned "+c.status);} const slug=(await c.json()).slug; for(const n of [1,2]){ const g=await fetch(H+3104+"/"+slug,{redirect:"manual"}); if(g.status!==302){return fail("GET /"+slug+" returned "+g.status+" on request "+n+", expected 302");} if(g.headers.get("location")!==URL1){return fail("the Location header was "+JSON.stringify(g.headers.get("location")));} } const l=await fetch(H+3104+"/links/"+slug); if(l.status!==200){return fail("GET /links/"+slug+" returned "+l.status);} const lb=await l.json(); if(lb.slug!==slug||lb.url!==URL1){return fail("GET /links/:slug returned "+JSON.stringify(lb));} if(lb.hits!==2){return fail("after two redirects hits was "+JSON.stringify(lb.hits)+", expected 2");} const l2=await fetch(H+3104+"/links/"+slug); const lb2=await l2.json(); if(lb2.hits!==2){return fail("reading GET /links/:slug changed the hit count to "+lb2.hits+"; only GET /:slug counts");} const hh=await fetch(H+3104+"/health"); if(hh.status!==200){return fail("GET /health returned "+hh.status+"; the :slug route must not shadow it");} await stop(p); done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

### T5 — Return 404 for an unknown slug on both lookup routes

`pending` · depends on: T4

An unknown slug is the common case for a public shortener, and it must be a clean 404 rather than a crash, a redirect to nowhere, or an empty 200. This covers both routes that take a slug, because they are handled by different controllers and it is easy to get one right and forget the other. A miss must also leave no trace in the database.

**Acceptance**

- A slug that does exist still works while unknown ones 404: `GET /:slug` redirects with 302 and `GET /links/:slug` returns 200 — the 404 is for misses only, not a blanket response.
- `GET /nope99` returns 404 with no `Location` header and no redirect.
- `GET /links/nope99` returns 404.
- A well-formed but unknown slug such as `aaaaaa` behaves the same on both routes.
- The 404 response body is JSON containing a human-readable `message`.
- Looking up unknown slugs creates no rows in the `links` table.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const sq=require("node:sqlite"); const db=G+"/t5.db"; migrate(db); const p=boot(3105,{DATABASE_PATH:db}); if(!(await up(3105))){return fail("the server did not come up on port 3105");} const c=await post(3105,{url:URL1}); if(c.status!==201){return fail("POST /links returned "+c.status+" while setting up the 404 checks");} const known=(await c.json()).slug; const kg=await fetch(H+3105+"/"+known,{redirect:"manual"}); if(kg.status!==302){return fail("GET /"+known+" for a known slug returned "+kg.status+"; a blanket 404 is not a 404 for unknown slugs only");} const kl=await fetch(H+3105+"/links/"+known); if(kl.status!==200){return fail("GET /links/"+known+" for a known slug returned "+kl.status+"; a blanket 404 is not a 404 for unknown slugs only");} for(const s of ["nope99","aaaaaa"]){ const g=await fetch(H+3105+"/"+s,{redirect:"manual"}); if(g.status!==404){return fail("GET /"+s+" returned "+g.status+", expected 404");} const l=await fetch(H+3105+"/links/"+s); if(l.status!==404){return fail("GET /links/"+s+" returned "+l.status+", expected 404");} const lj=await l.json().catch(()=>null); if(!lj||typeof lj.message!=="string"){return fail("the 404 for /links/"+s+" was not a JSON body with a message; got "+JSON.stringify(lj));} } const hh=await fetch(H+3105+"/health"); if(hh.status!==200){return fail("GET /health returned "+hh.status+" while unknown slugs 404");} await stop(p); const h=new sq.DatabaseSync(db); const n=h.prepare("select count(*) as c from links").get().c; h.close(); if(Number(n)!==1){return fail("the links table holds "+n+" rows, expected exactly the 1 link created here; looking up unknown slugs must create nothing");} done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

### T6 — Reject an invalid url with 400 naming the offending field

`pending` · depends on: T3

The only input the API takes is the url, so this is the whole of its validation surface. The brief pins which inputs are invalid (missing, empty, non-string, non-HTTP(S)) and requires the error to name the field, so a client can tell what it got wrong. Validation must reject without any network call — the service never checks that the url resolves, only that it is a syntactically valid http(s) url.

**Acceptance**

- `POST /links` returns 400 for each of: {} (missing url), {"url": null}, {"url": ""}, {"url": 123}, {"url": "not-a-url"}, {"url": "ftp://example.com/x"}.
- Each 400 response body names the offending field `url`.
- `POST /links` still returns 201 for a valid `http://` url and for a valid `https://` url.
- No link row is created for a rejected request.
- Validation is purely syntactic: the service never fetches the url or checks that it resolves.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const bad=[{},{url:null},{url:""},{url:123},{url:"not-a-url"},{url:"ftp://example.com/x"}]; const db=G+"/t6.db"; migrate(db); const p=boot(3106,{DATABASE_PATH:db}); if(!(await up(3106))){return fail("the server did not come up on port 3106");} for(const body of bad){ const r=await post(3106,body); if(r.status!==400){return fail("POST /links "+JSON.stringify(body)+" returned "+r.status+", expected 400");} const t=await r.text(); if(!/url/i.test(t)){return fail("the 400 for "+JSON.stringify(body)+" does not name the url field; body was "+t.slice(0,200));} } for(const u of ["http://example.com/x","https://example.com/a/very/long/path"]){ const r=await post(3106,{url:u}); if(r.status!==201){return fail("POST /links with the valid url "+u+" returned "+r.status+", expected 201");} } await stop(p); done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

### T7 — Guarantee unique slugs: seedable generation, collision retry, 500 only after five

`pending` · depends on: T3

Slugs are generated, so two creates can collide, and a collision must never reach the client as a duplicate or a raw database error. The brief requires this path to be exercisable rather than asserted, so slug generation goes behind an injectable provider and, when the `SLUG_SEED` environment variable is set, produces a deterministic sequence — a fresh process with the same seed generates the same slugs in the same order. That is what lets a test (and this task's gate) force a real collision instead of hoping for one. The retry budget is five candidates per create; the fifth failure is a 500.

**Acceptance**

- Slug generation sits behind an injectable provider that a test can replace, rather than being called inline as a free function in the service.
- With `SLUG_SEED` set, slug generation is deterministic: two fresh processes with the same seed produce the same sequence of slugs. With `SLUG_SEED` unset, slugs are random.
- Seeded slugs are still exactly 6 characters from [A-Za-z0-9].
- On a collision the service generates a fresh slug and retries, trying at most 5 candidates in total for one create.
- A create that collides fewer than 5 times still returns 201, with a slug that is not already in use.
- A create whose 5 candidates all collide returns 500, writes no row, and never returns an already-used slug.
- Unit tests substitute the slug provider to force a collision and cover both the retry-then-succeed and the exhaust-then-500 paths.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const sq=require("node:sqlite"); const S="gate-collision-seed"; const dbA=G+"/t7a.db"; migrate(dbA); let p=boot(3107,{DATABASE_PATH:dbA,SLUG_SEED:S}); if(!(await up(3107))){return fail("the server did not come up with SLUG_SEED set");} const first=[]; for(const n of [1,2]){ const r=await post(3107,{url:URL1}); if(r.status!==201){return fail("seeding run: create "+n+" returned "+r.status);} first.push((await r.json()).slug); } await stop(p); const dbB=G+"/t7b.db"; migrate(dbB); p=boot(3107,{DATABASE_PATH:dbB,SLUG_SEED:S}); if(!(await up(3107))){return fail("the server did not come back up on port 3107");} const rb=await post(3107,{url:URL1}); if(rb.status!==201){return fail("determinism check: create returned "+rb.status);} const sb=(await rb.json()).slug; await stop(p); if(sb!==first[0]){return fail("SLUG_SEED did not reproduce the same first slug ("+first[0]+" then "+sb+"); slug generation is not seedable, so a collision cannot be forced deterministically");} p=boot(3107,{DATABASE_PATH:dbA,SLUG_SEED:S}); if(!(await up(3107))){return fail("the server did not come back up on port 3107");} const rr=await post(3107,{url:URL1}); if(rr.status!==201){return fail("with the first 2 candidate slugs already taken POST /links returned "+rr.status+", expected 201 from the retry path");} const s3=(await rr.json()).slug; await stop(p); if(first.includes(s3)){return fail("the retry handed out an already-used slug "+s3);} const dbC=G+"/t7c.db"; migrate(dbC); const E="gate-exhaustion-seed"; p=boot(3107,{DATABASE_PATH:dbC,SLUG_SEED:E}); if(!(await up(3107))){return fail("the server did not come back up on port 3107");} for(let i=0;i<5;i++){ const r=await post(3107,{url:URL1}); if(r.status!==201){return fail("exhaustion setup: create "+(i+1)+" of 5 returned "+r.status);} } await stop(p); p=boot(3107,{DATABASE_PATH:dbC,SLUG_SEED:E}); if(!(await up(3107))){return fail("the server did not come back up on port 3107");} const rx=await post(3107,{url:URL1}); if(rx.status!==500){return fail("with all 5 candidate slugs colliding POST /links returned "+rx.status+", expected 500");} await stop(p); const h=new sq.DatabaseSync(dbC); const n=h.prepare("select count(*) as c from links").get().c; const d=h.prepare("select count(*) as c from (select slug from links group by slug having count(*) > 1)").get().c; h.close(); if(Number(n)!==5){return fail("after the exhausted create the links table holds "+n+" rows, expected 5");} if(Number(d)!==0){return fail("the links table contains duplicate slugs");} done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

### T8 — Serve a browsable Swagger UI at /api and the OpenAPI document at /api-json

`pending` · depends on: T4

The API has no web UI, so the Swagger page is the only way to look at it by hand. The document must be generated from the code by @nestjs/swagger — decorators on the controllers and DTOs — so that it cannot drift from the implementation; a hand-maintained spec file would defeat the point. All four functional paths must appear, and the create operation must describe both its request body and the link it returns.

**Acceptance**

- `GET /api` returns 200 and serves a browsable Swagger UI page.
- `GET /api-json` returns 200 and an OpenAPI document generated at runtime by @nestjs/swagger; there is no hand-written spec file checked into the repo.
- The document lists all four functional paths: /links, /{slug}, /links/{slug} and /health.
- The POST /links operation documents its request body including the `url` property.
- The POST /links operation documents a 201 response whose schema describes slug, url, hits and createdAt.
- Adding the documentation changes no behaviour: every status code and response body from T3 to T7 is unchanged.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const db=G+"/t8.db"; migrate(db); const p=boot(3108,{DATABASE_PATH:db}); if(!(await up(3108))){return fail("the server did not come up on port 3108");} const ui=await fetch(H+3108+"/api"); if(ui.status!==200){return fail("GET /api returned "+ui.status+", expected a browsable Swagger UI");} const html=await ui.text(); if(!/swagger/i.test(html)){return fail("GET /api did not serve a Swagger UI page");} const jr=await fetch(H+3108+"/api-json"); if(jr.status!==200){return fail("GET /api-json returned "+jr.status);} const doc=await jr.json(); const paths=Object.keys(doc.paths||{}); for(const want of ["/links","/health"]){if(!paths.includes(want)){return fail("the OpenAPI document has no "+want+" path; paths were: "+paths.join(" "));}} if(!paths.some(x=>/^\/\{[A-Za-z0-9_]+\}$/.test(x))){return fail("the OpenAPI document has no redirect path like /{slug}; paths were: "+paths.join(" "));} if(!paths.some(x=>/^\/links\/\{[A-Za-z0-9_]+\}$/.test(x))){return fail("the OpenAPI document has no /links/{slug} path; paths were: "+paths.join(" "));} const op=(doc.paths["/links"]||{}).post; if(!op){return fail("the OpenAPI document has no POST operation on /links");} if(!/url/.test(JSON.stringify(op.requestBody||{}))){return fail("POST /links has no documented request body naming url");} if(!op.responses||!op.responses["201"]||!op.responses["201"].content){return fail("POST /links has no documented 201 response with a body schema");} const all=JSON.stringify(doc); for(const k of ["slug","hits","createdAt"]){if(!all.includes("\""+k+"\"")){return fail("the OpenAPI document never describes "+k);}} await stop(p); done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

### T9 — Write the end-to-end acceptance test for the brief's worked example

`pending` · depends on: T5, T6, T7

Everything up to here is checked endpoint by endpoint; this is the one test that walks the whole worked example in order, over HTTP, as a client would. It has to thread the slug it received through every later request — an implementation that only works for a hardcoded slug must fail it. It runs under `npm run test:e2e`, which stays a separate command from the unit suite, and it must be self-contained: its own throwaway SQLite file, no network, seconds to run.

**Acceptance**

- `npm run test:e2e` exits 0 and runs at least four passing tests from `test/*.e2e-spec.ts`, with zero failures.
- The suite drives the running application over HTTP with supertest and uses the slug returned by the create in every subsequent request; no slug is hardcoded.
- It covers the worked example in order: create returns 201 with a matching slug, hits 0 and the submitted url; GET /links/{slug} returns 200 with hits 0; two GET /{slug} calls each return 302 with the target in `Location`; GET /links/{slug} then returns 200 with hits 2.
- It also covers GET /nope99 -> 404, GET /links/nope99 -> 404, POST /links with "not-a-url" -> 400, and the same url posted twice -> 201 with a different slug.
- `npm test` does not run the e2e specs and `npm run test:e2e` does not run the unit specs; both commands pass.
- The suite creates and cleans up its own SQLite database, makes no network call, needs no manual setup step, and passes when run twice in a row.
- The whole e2e run finishes in seconds.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && npm run test:e2e --silent -- --json --outputFile="$d/e2e.json" >/dev/null && npm run test:e2e --silent -- --json --outputFile="$d/e2e-again.json" >/dev/null && npm test --silent -- --json --outputFile="$d/unit.json" >/dev/null && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const e=require(G+"/e2e.json"); if(e.success!==true||e.numFailedTests!==0){return fail("npm run test:e2e reported "+e.numFailedTests+" failing tests");} if(e.numPassedTests<4){return fail("the e2e suite ran only "+e.numPassedTests+" passing tests; the worked example needs at least 4");} const efiles=(e.testResults||[]).map(t=>String(t.name||t.testFilePath||"")); if(!efiles.some(f=>/e2e-spec\.ts$/.test(f))){return fail("no test/*.e2e-spec.ts file ran under npm run test:e2e; files were: "+efiles.join(" "));} const e2=require(G+"/e2e-again.json"); if(e2.success!==true||e2.numFailedTests!==0){return fail("the second consecutive npm run test:e2e reported "+e2.numFailedTests+" failing tests; the suite must not depend on leftover state or a hardcoded slug");} if(e2.numPassedTests!==e.numPassedTests){return fail("the e2e suite ran "+e.numPassedTests+" tests then "+e2.numPassedTests+" on a second run");} const u=require(G+"/unit.json"); if(u.success!==true||u.numFailedTests!==0){return fail("npm test reported "+u.numFailedTests+" failing tests");} const ufiles=(u.testResults||[]).map(t=>String(t.name||t.testFilePath||"")); if(ufiles.some(f=>/e2e-spec\.ts$/.test(f))){return fail("npm test also runs the e2e specs; the unit and e2e commands must be separate");} done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

### T10 — Prove the built artifact boots, shuts down cleanly, and keeps its links across a restart

`pending` · depends on: T8, T9

Every other gate can be satisfied without the compiled application ever binding a port, which would let a broken build pass the entire suite. This task closes that hole: build, migrate a real SQLite file, start `dist/main.js` as a background process, exercise it over HTTP, stop it with SIGTERM, then start it again against the same file and check the links are still there with their hit counts. The work is the production edges — configuration through PORT and DATABASE_PATH, clean shutdown, no dev-only dependency at runtime — plus a README that records the commands.

**Acceptance**

- After `npm run build` and `npm run migrate`, `node dist/main.js` started with NODE_ENV=production, PORT and DATABASE_PATH comes up and answers `GET /health` with 200 and {"status":"ok"}.
- The same running artifact serves `GET /api-json` with 200 and an OpenAPI document listing at least the four functional paths.
- The same running artifact creates a link and redirects on it: POST /links -> 201, GET /{slug} -> 302.
- The process stays up on its own until signalled — it does not exit or crash while idle.
- On SIGTERM it shuts down within a few seconds, exiting 0 or terminated by SIGTERM; it never has to be SIGKILLed.
- Started again against the same DATABASE_PATH file, `GET /links/{slug}` returns the link created before the restart with its hit count intact.
- It runs from `dist/` with production dependencies only — no ts-node, no dev-only import on the startup path.
- `README.md` documents build, migrate, start, test and test:e2e using repo-relative paths only.

<details><summary>verify command</summary>

```sh
d=$(mktemp -d) && npm run build && GATE_DIR="$d" node -e 'const cp=require("node:child_process"); const H="http://127.0.0.1:"; const G=process.env.GATE_DIR; const URL1="https://example.com/a/very/long/path"; const KIDS=[]; const kill=()=>{for(const k of KIDS){try{k.kill("SIGKILL");}catch(e){}}}; const fail=(m)=>{console.error("GATE FAIL: "+m);kill();process.exit(1);}; const done=()=>{kill();process.exit(0);}; const migrate=(db)=>{cp.execFileSync("npm",["run","--silent","migrate"],{env:Object.assign({},process.env,{DATABASE_PATH:db}),stdio:["ignore","ignore","inherit"]});}; const boot=(port,env)=>{const p=cp.spawn(process.execPath,["dist/main.js"],{env:Object.assign({},process.env,{PORT:String(port)},env),stdio:["ignore","ignore","inherit"]});KIDS.push(p);return p;}; const stop=(p)=>new Promise(res=>{if(p.exitCode!==null||p.signalCode!==null){return res({code:p.exitCode,signal:p.signalCode});}const t=setTimeout(()=>{p.kill("SIGKILL");},8000);t.unref();p.once("exit",(code,signal)=>{clearTimeout(t);res({code:code,signal:signal});});p.kill("SIGTERM");}); const up=async(port)=>{for(let i=0;i<200;i++){try{const r=await fetch(H+port+"/health");if(r.status===200){return true;}}catch(e){}await new Promise(r=>setTimeout(r,100));}return false;}; const post=(port,body)=>fetch(H+port+"/links",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify(body)}); (async()=>{ const db=G+"/prod.db"; migrate(db); let p=boot(3110,{DATABASE_PATH:db,NODE_ENV:"production"}); if(!(await up(3110))){return fail("the built artifact did not answer GET /health within 20s");} const hb=await (await fetch(H+3110+"/health")).json().catch(()=>null); if(!hb||hb.status!=="ok"){return fail("GET /health body was "+JSON.stringify(hb));} const jr=await fetch(H+3110+"/api-json"); if(jr.status!==200){return fail("GET /api-json returned "+jr.status+" from the built artifact");} const doc=await jr.json(); if(!doc.paths||Object.keys(doc.paths).length<4){return fail("the served OpenAPI document lists "+Object.keys(doc.paths||{}).length+" paths, expected at least 4");} const c=await post(3110,{url:URL1}); if(c.status!==201){return fail("POST /links returned "+c.status+" from the built artifact");} const slug=(await c.json()).slug; const g=await fetch(H+3110+"/"+slug,{redirect:"manual"}); if(g.status!==302){return fail("GET /"+slug+" returned "+g.status+" from the built artifact");} if(p.exitCode!==null||p.signalCode!==null){return fail("the server process died on its own with code "+p.exitCode+" signal "+p.signalCode);} const s=await stop(p); if(s.code!==0&&s.code!==143&&s.signal!=="SIGTERM"){return fail("after SIGTERM the process exited with code "+s.code+" signal "+s.signal);} p=boot(3110,{DATABASE_PATH:db,NODE_ENV:"production"}); if(!(await up(3110))){return fail("the server did not come back up against the existing sqlite file");} const l=await fetch(H+3110+"/links/"+slug); if(l.status!==200){return fail("after a restart GET /links/"+slug+" returned "+l.status+"; links must survive a process restart");} const lb=await l.json(); if(lb.url!==URL1){return fail("after a restart the link url was "+JSON.stringify(lb.url));} if(lb.hits!==1){return fail("after a restart hits was "+JSON.stringify(lb.hits)+", expected 1");} await stop(p); done(); })().catch(e=>fail(String((e&&e.stack)||e)));'; rc=$?; rm -rf "$d"; exit $rc
```

</details>

