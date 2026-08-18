import { Global, Module } from '@nestjs/common';
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DEFAULT_DATABASE_PATH } from './migrate';

export const DATABASE_CONNECTION = 'DATABASE_CONNECTION';

@Global()
@Module({
  providers: [
    {
      provide: DATABASE_CONNECTION,
      useFactory: (): DatabaseSync => {
        const databasePath = process.env.DATABASE_PATH ?? DEFAULT_DATABASE_PATH;
        mkdirSync(dirname(databasePath), { recursive: true });
        return new DatabaseSync(databasePath);
      },
    },
  ],
  exports: [DATABASE_CONNECTION],
})
export class DatabaseModule {}
