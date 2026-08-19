import { randomBytes } from 'node:crypto';

export const SLUG_LENGTH = 6;
const SLUG_ALPHABET =
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

export const SLUG_GENERATOR = 'SLUG_GENERATOR';

export interface SlugGenerator {
  generate(): string;
}

function hashSeed(seed: string): number {
  let hash = 1779033703 ^ seed.length;
  for (let i = 0; i < seed.length; i++) {
    hash = Math.imul(hash ^ seed.charCodeAt(i), 3432918353);
    hash = (hash << 13) | (hash >>> 19);
  }
  return hash >>> 0;
}

// mulberry32: small deterministic PRNG, seeded from the hashed SLUG_SEED so
// that a fresh process with the same seed reproduces the same slug sequence.
function mulberry32(seed: number): () => number {
  let state = seed;
  return () => {
    state = (state + 0x6d2b79f5) | 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export class RandomSlugGenerator implements SlugGenerator {
  private readonly nextRandom?: () => number;

  constructor(seed?: string) {
    this.nextRandom = seed !== undefined ? mulberry32(hashSeed(seed)) : undefined;
  }

  generate(): string {
    if (this.nextRandom) {
      let slug = '';
      for (let i = 0; i < SLUG_LENGTH; i++) {
        const index = Math.floor(this.nextRandom() * SLUG_ALPHABET.length);
        slug += SLUG_ALPHABET[index];
      }
      return slug;
    }

    const bytes = randomBytes(SLUG_LENGTH);
    let slug = '';
    for (let i = 0; i < SLUG_LENGTH; i++) {
      slug += SLUG_ALPHABET[bytes[i] % SLUG_ALPHABET.length];
    }
    return slug;
  }
}
