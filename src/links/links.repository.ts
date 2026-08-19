import { Inject, Injectable } from '@nestjs/common';
import { DatabaseSync } from 'node:sqlite';
import { DATABASE_CONNECTION } from '../database/database.module';

export interface LinkRecord {
  slug: string;
  url: string;
  hits: number;
  createdAt: string;
}

interface LinkRow {
  slug: string;
  url: string;
  hits: number;
  created_at: string;
}

function toRecord(row: LinkRow): LinkRecord {
  return { slug: row.slug, url: row.url, hits: row.hits, createdAt: row.created_at };
}

function isUniqueSlugViolation(error: unknown): boolean {
  return (
    error instanceof Error &&
    (error as NodeJS.ErrnoException).code === 'ERR_SQLITE_ERROR' &&
    /UNIQUE constraint failed/.test(error.message)
  );
}

@Injectable()
export class LinksRepository {
  constructor(@Inject(DATABASE_CONNECTION) private readonly db: DatabaseSync) {}

  create(slug: string, url: string, createdAt: string): LinkRecord {
    this.db
      .prepare('INSERT INTO links (slug, url, hits, created_at) VALUES (?, ?, 0, ?)')
      .run(slug, url, createdAt);
    return { slug, url, hits: 0, createdAt };
  }

  /** Returns null on a slug collision instead of throwing, so callers can retry. */
  tryCreate(slug: string, url: string, createdAt: string): LinkRecord | null {
    try {
      return this.create(slug, url, createdAt);
    } catch (error) {
      if (isUniqueSlugViolation(error)) {
        return null;
      }
      throw error;
    }
  }

  findBySlug(slug: string): LinkRecord | undefined {
    const row = this.db
      .prepare('SELECT slug, url, hits, created_at FROM links WHERE slug = ?')
      .get(slug) as LinkRow | undefined;
    return row ? toRecord(row) : undefined;
  }

  incrementHits(slug: string): LinkRecord | undefined {
    this.db.prepare('UPDATE links SET hits = hits + 1 WHERE slug = ?').run(slug);
    return this.findBySlug(slug);
  }
}
