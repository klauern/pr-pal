# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

PR Pal is a Rails 8.0 web application for managing pull requests with LLM integration. It features user authentication, encrypted API key storage for LLM providers, and modern Rails tooling.

## Architecture

### Core Models
- **User**: Authentication with normalized emails and secure passwords, encrypted GitHub tokens
- **Session**: Session management with IP/user agent tracking  
- **LlmApiKey**: Encrypted storage for different LLM provider API keys
<<<<<<< HEAD
- **Repository**: GitHub repository tracking (owner/name)
- **PullRequestReview**: Core PR data with GitHub sync, CI status, comments
- **LlmConversationMessage**: Conversation threads for PR discussions

### GitHub Integration Architecture
- **Data Provider Pattern**: Configurable GitHub API vs dummy data via `USE_DUMMY_DATA` env var
- **Background Sync**: `PullRequestSyncJob` + `PullRequestSyncer` for automated PR updates
- **GitHub API Client**: Octokit-based with retry logic and rate limiting
- **PR Status Tracking**: CI status, comments, reviews synced from GitHub API
=======
- **Repository**: GitHub repositories linked to users
- **PullRequest**: Individual PRs with GitHub metadata
- **PullRequestReview**: Central entity linking users to PR reviews and LLM conversations
- **LlmConversationMessage**: Individual messages in LLM conversations
>>>>>>> main

### Authentication System
- Custom authentication using `Authentication` concern in controllers
- Session-based auth with signed cookies, no external auth gems
- Rate limiting (10 attempts per 3 minutes) and modern browser requirements

### Frontend Stack
- **Hotwire** (Turbo + Stimulus) for interactive functionality
- **TailwindCSS 4.x** for styling
- **Bun** for JavaScript bundling and dependency management
- Assets build to `app/assets/builds/` directory

## Essential Development Commands

### Setup
```bash
bundle install && bun install
bin/rails db:create db:migrate db:seed
```

### Development Server
```bash
bin/dev  # Starts Rails server + asset watchers (uses Procfile.dev)
```

### Testing
```bash
bin/rails test                    # Run all tests
bin/rails test:system             # Run system tests only
bin/rails test test/models/       # Run specific test directory
<<<<<<< HEAD
bin/rails test test/models/user_test.rb:15  # Run specific test method/line
rake test:coverage                # Run tests with coverage reporting
rake test:coverage_open           # Run tests with coverage and open report
=======
bin/rails test test/models/user_test.rb  # Run single test file
rake test:coverage                 # Run tests with coverage reporting
rake test:coverage_open           # Run tests with coverage and open report
rake test:coverage:upload         # Run tests with coverage and upload to Codecov
>>>>>>> main
```

### Database Operations
```bash
bin/rails db:migrate
bin/rails db:rollback
bin/rails dbconsole
bin/rails db:reset                # Drop, create, migrate, seed
```

### Asset Building
```bash
bun run build         # JavaScript bundling
bun run build:css     # TailwindCSS compilation
# Add --watch to either for development mode
```

### Code Quality & Type Checking
```bash
<<<<<<< HEAD
bundle exec rubocop              # Ruby linting
bundle exec rubocop -a           # Auto-fix linting issues
bundle exec brakeman             # Security scanning
bundle exec tapioca generate     # Generate RBI files for Sorbet
srb tc                          # Run Sorbet type checker
=======
bundle exec rubocop -A  # Ruby linting with auto-fix
bundle exec brakeman    # Security scanning
>>>>>>> main
```

## Deployment (Kamal)

```bash
bin/kamal deploy      # Deploy to production
bin/kamal console     # Rails console on production
bin/kamal shell       # SSH into production container
bin/kamal logs        # Tail production logs
bin/kamal dbc         # Production database console
```

## Key Architectural Patterns

### Data Provider Strategy
Switch between GitHub API and dummy data via environment configuration:
- Set `USE_DUMMY_DATA=true` for development without GitHub API
- Data providers in `app/services/` implement consistent interface
- Configuration via `config/initializers/data_providers.rb`

### Background Processing
- **Solid Queue** for job processing (Rails 8 default)
- `PullRequestSyncJob` syncs all user repositories automatically
- Error handling with fallback to basic PR creation

### Tab Management System
- Session-based PR tab tracking for multi-PR workflows
- Automatic cleanup when repositories are deleted
- Hotwire-powered real-time tab updates

## Architecture Notes

- **Rails 8.0** with Solid Queue/Cache/Cable for background processing
- **SQLite3** database for all environments with persistent volumes in production
- **Propshaft** asset pipeline with Bun instead of traditional Webpacker
- **Docker** deployment using multi-stage builds with Thruster for asset serving
- **Sorbet** type checking with RBI files generated by Tapioca
- Modern Rails patterns: no Devise, no external auth gems, leveraging built-in features
- **Security**: CSRF protection, encrypted token storage, Content Security Policy, Brakeman scanning

## Data Provider System

### Environment-Based Data Sources
- **Development/Test**: `USE_DUMMY_DATA=true` (default) - generates realistic dummy data
- **Production**: `USE_DUMMY_DATA=false` (default) - uses real GitHub API data
- Override with environment variable: `USE_DUMMY_DATA=true/false bin/rails server`

### Visual Indicators
- Dummy data mode shows "🎭 DUMMY DATA MODE" indicator in development
- Logs show current data provider configuration on startup

## Service Layer Architecture

### Data Provider Pattern
- **PullRequestDataProvider**: Abstract base class defining interface for PR data sources
- **GithubPullRequestDataProvider**: Real GitHub API integration using Octokit
- **DummyPullRequestDataProvider**: Generates realistic dummy data for testing/demo
- **PullRequestDataProviderFactory**: Factory that chooses provider based on user config and environment

### Core Services
- **PullRequestSyncer**: Main service for syncing PRs from external sources to database
- **RubyLlmService**: LLM integration service for AI-powered PR analysis

### Model Relationships
```
User (1) ─── (many) Repository (1) ─── (many) PullRequest
 │                      │                        │
 │                      └── (many) PullRequestReview ──┘
 │                                     │
 │                                     └── (many) LlmConversationMessage
 │
 └── (many) LlmApiKey, Session
```

## Testing Setup

Uses **Minitest** with parallel execution, **Capybara + Selenium** for system tests, and fixture-based test data. Tests are organized in standard Rails structure under `test/`. SimpleCov provides coverage reporting with optional Codecov integration.

### Test Discipline
- **Tests must be run every time work is done**
- **Never leave work in progress with failing tests**
- All new features, bug fixes, and refactors must have passing tests before completion
- Custom rake tasks handle asset building, database preparation, and coverage reporting automatically

### Fixture-Based Testing
- Comprehensive fixtures cover realistic scenarios (open/closed/merged PRs, different user configurations)
- Tests prefer fixtures over manual object creation for consistency and performance
- Fixtures include complex association chains for integration testing
- Use `users(:github_user)`, `pull_requests(:pr_closed)`, etc. for predefined scenarios

### Workflow Reminders
- Always run `bundle exec rubocop -A` after completing tasks to ensure we fix formatting/linting issues

## Background Job Architecture

### Core Jobs
- **PullRequestSyncJob**: Repository-wide PR synchronization from GitHub API
- **AutoSyncPrJob**: Smart auto-sync with staleness detection and duplicate prevention logic
- **ProcessLlmResponseJob**: Asynchronous LLM processing with real-time broadcasting via Turbo Streams

### Job Patterns
- Jobs use Rails 8 Solid Queue for background processing
- Auto-sync jobs respect data freshness thresholds (15 minutes for reviews, 1 hour for stale data)
- Duplicate job prevention through sync status checking

## Real-Time Features

### Turbo Streams Integration
- Live updates during LLM conversation processing
- Real-time sync status broadcasting to user interface
- Progressive enhancement for conversation building

### Session-Based Tab Management
- Rails sessions track "open PR tabs" per user (`session[:open_pr_tabs]`)
- `ApplicationController` includes automatic tab cleanup logic
- Tab state persists across requests and is cleaned up on logout

## LLM Integration Architecture

### Multi-Provider Support
- `RubyLlmService` handles OpenAI and Anthropic providers
- User preferences stored in `default_llm_provider` and `default_llm_model` fields
- Temporary API key injection during service calls for security
- Provider-specific conversation message handling

### LLM Conversation Threading
- `LlmConversationMessage` model with ordering and timestamp indexing
- Auto-assignment of message order for conversation flow
- Support for placeholder messages during processing

## Authentication & Security Details

### Custom Authentication System
- Uses `Authentication` concern instead of external gems like Devise
- Session management with IP address and user agent tracking for security
- `Current` (ActiveSupport::CurrentAttributes) for thread-safe user context
- Rate limiting: 10 attempts per 3 minutes

### Encryption & Security
- GitHub tokens and LLM API keys encrypted at rest (disabled in test environment)
- Content Security Policy configured
- Brakeman security scanning integration
- CSRF protection enabled

## Development Configuration

### Data Provider Switching
- Environment variable `USE_DUMMY_DATA` controls data source
- Development indicator "🎭 DUMMY DATA MODE" shown in UI when using dummy data
- Runtime provider access via `DataProviders.pull_request_data_provider`
