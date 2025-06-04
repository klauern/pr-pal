# Tech Context

## Technologies Used

- **Ruby**: 3.4.4 (specified in .ruby-version)
- **Rails**: 8.0.2 (modern Rails with built-in authentication)
- **Database**: SQLite3 (>= 2.1) for development
- **Asset Pipeline**: Propshaft (modern Rails asset pipeline)
- **JavaScript**: Bundled with jsbundling-rails, using Bun
- **CSS**: Bundled with cssbundling-rails, using Tailwind CSS
- **Frontend Framework**: Hotwire (Turbo + Stimulus)
- **Authentication**: bcrypt for password hashing
- **Caching/Queue/Cable**: Solid Cache, Solid Queue, Solid Cable (for background jobs)
- **Development Tools**:
  - Solargraph (Ruby language server)
  - solargraph-rails (Rails-specific Solargraph features)
  - Sorbet (gradual type checker for Ruby)
  - Tapioca (RBI file generator for Sorbet)
  - RuboCop Rails Omakase (code styling)
  - Brakeman (security analysis)

## Development Setup

1. **Ruby Environment**: Ruby 3.4.4 (managed via mise/rbenv/rvm)
2. **Dependencies**: Run `bundle install` to install gems
3. **Asset Building**: Uses Bun for JavaScript bundling
4. **Database**: SQLite3 for local development
5. **Solargraph Setup**:
   - Run `rake solargraph:setup` to cache gem documentation
   - Configuration in `.solargraph.yml`
   - Provides IDE features like autocomplete and go-to-definition
6. **Sorbet Setup**:
   - Run `bundle exec srb init` to initialize Sorbet
   - Run `bin/tapioca init` to generate RBI files for gems
   - Run `bin/tapioca dsl` to generate RBI files for Rails DSLs
   - Run `bundle exec srb tc` to type check the project
   - Configuration in `sorbet/config`

## Technical Constraints

- **Ruby Version**: Requires Ruby 3.4.4+ for Rails 8.0 compatibility
- **Database**: Currently using SQLite3 (suitable for development, may need PostgreSQL for production)
- **Asset Pipeline**: Modern approach using Propshaft instead of Sprockets
- **YARD Compatibility**: Some warnings with Ruby 3.4.4 and YARD parser for beginless ranges

## Dependencies

- **Background Jobs**: Solid Queue for processing background tasks like PR synchronization.
- **External Services**: None currently configured
- **Third-party Integrations**:
  - Future OIDC providers (Auth0/Okta) planned
  - Kamal for deployment
  - Thruster for HTTP acceleration

## Tool Usage Patterns

- **Version Control**: Git (standard Rails .gitignore patterns)
- **Code Quality**:
  - RuboCop with Rails Omakase configuration
  - Brakeman for security scanning
  - Solargraph for IDE integration and code intelligence
  - Sorbet for gradual type checking
- **Testing**: Rails built-in testing with Capybara and Selenium
  - `rails-controller-testing` gem for Rails 8 controller test helpers (assigns, etc.)
- **Development Server**: Puma web server
- **Task Management**: Rake tasks for common operations
  - `rake solargraph:setup` - Initial Solargraph configuration
  - `rake solargraph:rebuild` - Clear and rebuild cache
  - `rake solargraph:scan` - Check workspace for problems
- **Deployment**: Kamal for containerized deployment
