import { IsNotEmpty, IsString, IsUrl } from 'class-validator';

export class CreateLinkDto {
  @IsString()
  @IsNotEmpty()
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true })
  url: string;
}
