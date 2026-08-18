import { Module } from '@nestjs/common';
import { HealthController } from './health/health.controller';
import { DatabaseModule } from './database/database.module';
import { LinksModule } from './links/links.module';

@Module({
  imports: [DatabaseModule, LinksModule],
  controllers: [HealthController],
  providers: [],
})
export class AppModule {}
