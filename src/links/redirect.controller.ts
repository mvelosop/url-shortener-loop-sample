import { Controller, Get, Param, Redirect } from '@nestjs/common';
import { LinksService } from './links.service';

@Controller()
export class RedirectController {
  constructor(private readonly linksService: LinksService) {}

  @Get(':slug')
  @Redirect()
  redirect(@Param('slug') slug: string): { url: string } {
    const link = this.linksService.redirect(slug);
    return { url: link.url };
  }
}
