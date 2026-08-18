import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ApiBody, ApiOperation, ApiParam, ApiResponse, ApiTags } from '@nestjs/swagger';
import { CreateLinkDto } from './dto/create-link.dto';
import { LinkDto } from './dto/link.dto';
import { LinkRecord } from './links.repository';
import { LinksService } from './links.service';

@ApiTags('links')
@Controller('links')
export class LinksController {
  constructor(private readonly linksService: LinksService) {}

  @Post()
  @ApiOperation({ summary: 'Shorten a url.' })
  @ApiBody({ type: CreateLinkDto })
  @ApiResponse({ status: 201, description: 'The created link.', type: LinkDto })
  @ApiResponse({ status: 400, description: 'The url is missing, empty, non-string or non-HTTP(S).' })
  create(@Body() dto: CreateLinkDto): LinkRecord {
    return this.linksService.create(dto.url);
  }

  @Get(':slug')
  @ApiOperation({ summary: 'Read a link and its hit count.' })
  @ApiParam({ name: 'slug', example: 'aB3xK9' })
  @ApiResponse({ status: 200, description: 'The link.', type: LinkDto })
  @ApiResponse({ status: 404, description: 'No link exists for the given slug.' })
  findOne(@Param('slug') slug: string): LinkRecord {
    return this.linksService.findBySlug(slug);
  }
}
