import { Body, Controller, Post } from '@nestjs/common';
import { CreateLinkDto } from './dto/create-link.dto';
import { LinkRecord } from './links.repository';
import { LinksService } from './links.service';

@Controller('links')
export class LinksController {
  constructor(private readonly linksService: LinksService) {}

  @Post()
  create(@Body() dto: CreateLinkDto): LinkRecord {
    return this.linksService.create(dto.url);
  }
}
