import { Controller, Get, Param, Redirect } from '@nestjs/common';
import { ApiOperation, ApiParam, ApiResponse, ApiTags } from '@nestjs/swagger';
import { LinksService } from './links.service';

@ApiTags('redirect')
@Controller()
export class RedirectController {
  constructor(private readonly linksService: LinksService) {}

  @Get(':slug')
  @Redirect()
  @ApiOperation({ summary: 'Follow a slug and count the hit.' })
  @ApiParam({ name: 'slug', example: 'aB3xK9' })
  @ApiResponse({ status: 302, description: 'Redirects to the target url.' })
  @ApiResponse({ status: 404, description: 'No link exists for the given slug.' })
  redirect(@Param('slug') slug: string): { url: string } {
    const link = this.linksService.redirect(slug);
    return { url: link.url };
  }
}
