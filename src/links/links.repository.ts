import { Inject, Injectable } from '@nestjs/common';
import { DatabaseSync } from 'node:sqlite';
import { DATABASE_CONNECTION } from '../database/database.module';

export interface LinkRecord {
  slug: string;
  url: string;
  hits: number;
  createdAt: string;
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
}
