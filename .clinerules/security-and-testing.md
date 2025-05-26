## Brief overview

Security-focused development guidelines for Rails applications, emphasizing Brakeman security scanning alongside standard testing practices. These rules ensure robust security practices are maintained throughout feature development.

## Security scanning workflow

- Always run `bundle exec brakeman` after implementing features or fixes
- Address all Brakeman warnings before considering work complete
- Create secure helper methods when dealing with user-generated content in views
- Use HTML escaping (`html_escape()` or `h()`) for dynamic text content
- Validate URLs to prevent XSS attacks, especially for external links
- Default to safe fallbacks (like "#") for invalid or potentially malicious URLs

## Testing and quality assurance

- Run both Rails tests and Brakeman scans as part of the development workflow
- Security scanning is as important as functional testing
- Document security implementations in memory bank files
- Update progress tracking to include security status

## View security patterns

- Use helper methods instead of directly outputting model attributes in views
- Centralize security logic in reusable helper methods
- Validate URLs by checking for safe schemes (https://, http://) or specific domains
- Keep security controls visible and explicit rather than hidden

## Memory bank maintenance

- Update progress.md and activeContext.md after completing security fixes
- Include security implementation details in documentation
- Track Brakeman scan status as part of "What Works" sections
- Condense memory bank entries to prevent bloat while maintaining key information
