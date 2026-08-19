import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { AppModule } from '../src/app.module';
import { migrate } from '../src/database/migrate';

describe('Links (e2e)', () => {
  let app: INestApplication;
  let dbDir: string;
  let slug: string;
  const url = 'https://example.com/a/very/long/path';

  beforeAll(async () => {
    dbDir = mkdtempSync(join(tmpdir(), 'url-shortener-e2e-'));
    process.env.DATABASE_PATH = join(dbDir, 'links.db');
    migrate();

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
    rmSync(dbDir, { recursive: true, force: true });
    delete process.env.DATABASE_PATH;
  });

  it('creates a link and returns 201 with a matching slug', async () => {
    const res = await request(app.getHttpServer()).post('/links').send({ url }).expect(201);
    expect(res.body.slug).toMatch(/^[A-Za-z0-9]{6}$/);
    expect(res.body.hits).toBe(0);
    expect(res.body.url).toBe(url);
    slug = res.body.slug;
  });

  it('reads the new link with hits at 0', async () => {
    const res = await request(app.getHttpServer()).get(`/links/${slug}`).expect(200);
    expect(res.body.hits).toBe(0);
  });

  it('redirects to the target url, twice', async () => {
    const first = await request(app.getHttpServer()).get(`/${slug}`).expect(302);
    expect(first.headers.location).toBe(url);

    const second = await request(app.getHttpServer()).get(`/${slug}`).expect(302);
    expect(second.headers.location).toBe(url);
  });

  it('reads the link again and sees both redirects counted', async () => {
    const res = await request(app.getHttpServer()).get(`/links/${slug}`).expect(200);
    expect(res.body.hits).toBe(2);
  });

  it('returns 404 for an unknown slug on both lookup routes', async () => {
    await request(app.getHttpServer()).get('/nope99').expect(404);
    await request(app.getHttpServer()).get('/links/nope99').expect(404);
  });

  it('rejects a non-url with 400', async () => {
    await request(app.getHttpServer()).post('/links').send({ url: 'not-a-url' }).expect(400);
  });

  it('creates a second link for the same url with a different slug', async () => {
    const res = await request(app.getHttpServer()).post('/links').send({ url }).expect(201);
    expect(res.body.slug).toMatch(/^[A-Za-z0-9]{6}$/);
    expect(res.body.slug).not.toBe(slug);
  });
});
