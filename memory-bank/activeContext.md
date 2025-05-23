# Active Context

## Current Work Focus

- Successfully set up Sorbet with Tapioca for gradual type checking in the Rails application.
- Completed development tooling setup including both Solargraph and Sorbet for enhanced code quality and developer experience.

## Recent Changes

- Initialized memory bank with core documentation files.
- Decided to use Rails' built-in authentication generator instead of Devise for a simpler starting point and better alignment with Rails conventions.
- Added Solargraph gem and solargraph-rails plugin to Gemfile for development environment.
- Created .solargraph.yml configuration file optimized for Rails development.
- Added Rake tasks for Solargraph management (setup, clear, rebuild, scan).
- Successfully initialized Sorbet with `bundle exec srb init`.
- Generated comprehensive RBI files with Tapioca:
  - `bin/tapioca init` - Generated RBI files for all gems
  - `bin/tapioca dsl` - Generated RBI files for Rails DSLs and application models
- Sorbet type checking is now available with `bundle exec srb tc`.
- **FIXED**: Added missing routes for TabsController to resolve `undefined method 'select_tab_tabs_path'` error.
- Added routes for `select_tab`, `open_pr`, and `close_pr` actions in `config/routes.rb`.
- All tests now pass (1 run, 2 assertions, 0 failures, 0 errors).

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
