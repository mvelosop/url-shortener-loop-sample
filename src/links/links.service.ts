import {
  Inject,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { LinkRecord, LinksRepository } from './links.repository';
import { SLUG_GENERATOR, SlugGenerator } from './slug.generator';

export const MAX_SLUG_ATTEMPTS = 5;

@Injectable()
export class LinksService {
  constructor(
    private readonly repository: LinksRepository,
    @Inject(SLUG_GENERATOR) private readonly slugGenerator: SlugGenerator,
  ) {}

  create(url: string): LinkRecord {
    const createdAt = new Date().toISOString();
    for (let attempt = 0; attempt < MAX_SLUG_ATTEMPTS; attempt++) {
      const slug = this.slugGenerator.generate();
      const record = this.repository.tryCreate(slug, url, createdAt);
      if (record) {
        return record;
      }
    }
    throw new InternalServerErrorException(
      `Could not generate a unique slug after ${MAX_SLUG_ATTEMPTS} attempts`,
    );
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
