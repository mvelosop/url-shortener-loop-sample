import { Injectable } from '@nestjs/common';
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
}
