import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString, IsUrl } from 'class-validator';

export class CreateLinkDto {
  @ApiProperty({
    description: 'The long url to shorten.',
    example: 'https://example.com/a/long/path',
  })
  @IsString()
  @IsNotEmpty()
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true })
  url: string;
}
