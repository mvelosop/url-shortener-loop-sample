import { ApiProperty } from '@nestjs/swagger';

export class LinkDto {
  @ApiProperty({ description: 'The generated slug.', example: 'aB3xK9' })
  slug: string;

  @ApiProperty({ description: 'The target url.', example: 'https://example.com/a/long/path' })
  url: string;

  @ApiProperty({ description: 'How many times the slug has been followed.', example: 0 })
  hits: number;

  @ApiProperty({
    description: 'When the link was created, ISO-8601 UTC with milliseconds.',
    example: '2026-08-18T21:00:00.000Z',
  })
  createdAt: string;
}
