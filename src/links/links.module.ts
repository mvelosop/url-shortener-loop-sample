import { Module } from '@nestjs/common';
import { LinksController } from './links.controller';
import { RedirectController } from './redirect.controller';
import { LinksRepository } from './links.repository';
import { LinksService } from './links.service';
import { RandomSlugGenerator, SLUG_GENERATOR } from './slug.generator';

@Module({
  controllers: [LinksController, RedirectController],
  providers: [
    LinksService,
    LinksRepository,
    {
      provide: SLUG_GENERATOR,
      useFactory: () => new RandomSlugGenerator(process.env.SLUG_SEED),
    },
  ],
})
export class LinksModule {}
