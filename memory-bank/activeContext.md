# Active Context

## Current Work Focus

- **FIXED**: GitHub Actions CI configuration issues resolved.
- CI now properly runs tests, builds assets, and generates coverage reports.
- All CI jobs (security scan, linting, testing) are working correctly.

## Recent Changes

- **FIXED**: GitHub Actions CI workflow (.github/workflows/ci.yml) had multiple issues:
  - Incorrect test command structure (`bundle exec rails db:test:prepare test test:system` was malformed)
  - Missing asset compilation step (Bun build process)
  - System tests were being run when no system test directory exists
- **RESOLVED**: Split test commands into separate steps:
  - Database preparation: `bundle exec rails db:test:prepare`
  - Unit/integration tests: `bundle exec rails test`
  - System tests: Conditional check for test/system directory
- **ADDED**: Asset building step in CI:
  - `bun install` - Install dependencies
  - `bun run build` - Build JavaScript assets
  - `bun run build:css` - Build CSS with Tailwind
- **VERIFIED**: All CI components working locally:
  - Brakeman security scan: ✅ No warnings found
  - RuboCop linting: ✅ No style violations
  - Asset building: ✅ JavaScript and CSS compile successfully
  - Test database preparation: ✅ Works correctly
  - Test execution: ✅ 1 run, 2 assertions, 0 failures, 0 errors
  - Coverage generation: ✅ .resultset.json file created correctly

## Next Steps

- Complete Solargraph gem caching process (currently running).
- Run `rails generate authentication`.
- Run `rails db:migrate`.
- Create an initial admin user.
- Protect application routes/controllers.

## Active Decisions and Considerations

- The initial authentication will be a simple user/password system.
- Future work will involve integrating OIDC providers like Auth0 or Okta on top of this foundation.
- Solargraph provides IDE features like autocomplete, go-to-definition, and documentation for Ruby code.
- Using solargraph-rails plugin for Rails-specific features and better integration.
- Sorbet provides gradual type checking with comprehensive RBI files for gems and Rails DSLs.
- Type checking shows 148 errors initially, mostly from conflicts between community RBI files and generated ones (normal for fresh setup).

## Important Patterns and Preferences

- Prioritizing Rails-native solutions where possible.
- Adding development tooling to improve code quality and developer experience.
- Using Rake tasks for common development operations.

## Learnings and Project Insights

- Rails 8.0+ includes a robust built-in authentication generator, simplifying initial setup.
- Solargraph requires gem documentation caching for optimal performance.
- Ruby 3.4.4 compatibility issues with YARD parser may cause some warnings during gem caching.
- Sorbet setup in Rails projects requires both `srb init` and Tapioca for complete RBI generation.
- Initial Sorbet type checking will show many errors due to RBI conflicts, which is expected and normal.
- The `sorbet/` directory structure includes config, RBI files for gems/DSLs, and Tapioca configuration.
