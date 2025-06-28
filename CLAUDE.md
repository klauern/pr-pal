# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

PR Pal is a Rails 8.0 web application for managing pull requests with LLM integration. It features user authentication, encrypted API key storage for LLM providers, and modern Rails tooling.

## Architecture

### Core Models
- **User**: Authentication with normalized emails and secure passwords
- **Session**: Session management with IP/user agent tracking  
- **LlmApiKey**: Encrypted storage for different LLM provider API keys
- **Repository**: GitHub repositories linked to users
- **PullRequest**: Individual PRs with GitHub metadata
- **PullRequestReview**: Central entity linking users to PR reviews and LLM conversations
- **LlmConversationMessage**: Individual messages in LLM conversations

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
bin/rails test test/models/user_test.rb  # Run single test file
rake test:coverage                 # Run tests with coverage reporting
rake test:coverage_open           # Run tests with coverage and open report
rake test:coverage:upload         # Run tests with coverage and upload to Codecov
```

### Database Operations
```bash
bin/rails db:migrate
bin/rails db:rollback
bin/rails dbconsole
```

### Asset Building
```bash
bun run build         # JavaScript bundling
bun run build:css     # TailwindCSS compilation
# Add --watch to either for development mode
```

### Code Quality
```bash
bundle exec rubocop -A  # Ruby linting with auto-fix
bundle exec brakeman    # Security scanning
```

## Deployment (Kamal)

```bash
bin/kamal deploy      # Deploy to production
bin/kamal console     # Rails console on production
bin/kamal shell       # SSH into production container
bin/kamal logs        # Tail production logs
bin/kamal dbc         # Production database console
```

## Architecture Notes

- **Rails 8.0** with Solid Queue/Cache/Cable for background processing
- **SQLite3** database for all environments with persistent volumes in production
- **Propshaft** asset pipeline with Bun instead of traditional Webpacker
- **Docker** deployment using multi-stage builds with Thruster for asset serving
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

### Workflow Reminders
- Always run `bundle exec rubocop -A` after completing tasks to ensure we fix formatting/linting issues