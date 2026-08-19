import { InternalServerErrorException } from '@nestjs/common';
import { LinksRepository } from './links.repository';
import { LinksService, MAX_SLUG_ATTEMPTS } from './links.service';
import { SlugGenerator } from './slug.generator';

const URL = 'https://example.com/a/very/long/path';

class QueueSlugGenerator implements SlugGenerator {
  constructor(private readonly slugs: string[]) {}

  generate(): string {
    const next = this.slugs.shift();
    if (!next) {
      throw new Error('QueueSlugGenerator ran out of slugs');
    }
    return next;
  }
}

function fakeRepository(existingSlugs: string[]) {
  const taken = new Set(existingSlugs);
  return {
    tryCreate: jest.fn((slug: string, url: string, createdAt: string) => {
      if (taken.has(slug)) {
        return null;
      }
      taken.add(slug);
      return { slug, url, hits: 0, createdAt };
    }),
  } as unknown as LinksRepository;
}

describe('LinksService', () => {
  it('returns 201-worthy record on the first try when there is no collision', () => {
    const repository = fakeRepository([]);
    const service = new LinksService(repository, new QueueSlugGenerator(['abcdef']));

    const record = service.create(URL);

    expect(record.slug).toBe('abcdef');
    expect(repository.tryCreate).toHaveBeenCalledTimes(1);
  });

  it('retries past collisions and succeeds with a slug not already in use', () => {
    const repository = fakeRepository(['aaaaaa', 'bbbbbb']);
    const generator = new QueueSlugGenerator(['aaaaaa', 'bbbbbb', 'cccccc']);
    const service = new LinksService(repository, generator);

    const record = service.create(URL);

    expect(record.slug).toBe('cccccc');
    expect(repository.tryCreate).toHaveBeenCalledTimes(3);
  });

  it('throws a 500 after exhausting all candidates and writes no row', () => {
    const repository = fakeRepository(['a', 'b', 'c', 'd', 'e']);
    const generator = new QueueSlugGenerator(['a', 'b', 'c', 'd', 'e']);
    const service = new LinksService(repository, generator);

    expect(() => service.create(URL)).toThrow(InternalServerErrorException);
    expect(repository.tryCreate).toHaveBeenCalledTimes(MAX_SLUG_ATTEMPTS);
  });
});
