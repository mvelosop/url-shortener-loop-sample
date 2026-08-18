import { RandomSlugGenerator } from './slug.generator';

const SLUG_PATTERN = /^[A-Za-z0-9]{6}$/;

describe('RandomSlugGenerator', () => {
  it('produces well-formed slugs when unseeded', () => {
    const generator = new RandomSlugGenerator();
    for (let i = 0; i < 20; i++) {
      expect(generator.generate()).toMatch(SLUG_PATTERN);
    }
  });

  it('produces well-formed slugs when seeded', () => {
    const generator = new RandomSlugGenerator('a-fixed-seed');
    for (let i = 0; i < 20; i++) {
      expect(generator.generate()).toMatch(SLUG_PATTERN);
    }
  });

  it('reproduces the same sequence across fresh instances given the same seed', () => {
    const a = new RandomSlugGenerator('same-seed').generate();
    const b = new RandomSlugGenerator('same-seed').generate();
    expect(a).toBe(b);
  });

  it('reproduces a full sequence, not just the first slug', () => {
    const genA = new RandomSlugGenerator('sequence-seed');
    const genB = new RandomSlugGenerator('sequence-seed');
    const a = Array.from({ length: 5 }, () => genA.generate());
    const b = Array.from({ length: 5 }, () => genB.generate());
    expect(a).toEqual(b);
  });

  it('produces different sequences for different seeds', () => {
    const a = new RandomSlugGenerator('seed-one').generate();
    const b = new RandomSlugGenerator('seed-two').generate();
    expect(a).not.toBe(b);
  });

  it('is unseeded by default and produces varying slugs', () => {
    const generator = new RandomSlugGenerator();
    const slugs = new Set(Array.from({ length: 20 }, () => generator.generate()));
    expect(slugs.size).toBeGreaterThan(1);
  });
});
