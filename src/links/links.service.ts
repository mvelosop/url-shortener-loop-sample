import { Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { LinkRecord, LinksRepository } from './links.repository';

const SLUG_ALPHABET =
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
const SLUG_LENGTH = 6;

function generateSlug(): string {
  const bytes = randomBytes(SLUG_LENGTH);
  let slug = '';
  for (let i = 0; i < SLUG_LENGTH; i++) {
    slug += SLUG_ALPHABET[bytes[i] % SLUG_ALPHABET.length];
  }
  return slug;
}

@Injectable()
export class LinksService {
  constructor(private readonly repository: LinksRepository) {}

  create(url: string): LinkRecord {
    const slug = generateSlug();
    const createdAt = new Date().toISOString();
    return this.repository.create(slug, url, createdAt);
  }

  findBySlug(slug: string): LinkRecord {
    const link = this.repository.findBySlug(slug);
    if (!link) {
      throw new NotFoundException(`No link found for slug "${slug}"`);
    }
    return link;
  }

  redirect(slug: string): LinkRecord {
    const link = this.repository.incrementHits(slug);
    if (!link) {
      throw new NotFoundException(`No link found for slug "${slug}"`);
    }
    return link;
  }
}
