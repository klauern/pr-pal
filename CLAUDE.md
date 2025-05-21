# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

PR Pal is a Rails 8.0 web application for managing pull requests with LLM integration. It features user authentication, encrypted API key storage for LLM providers, and modern Rails tooling.

## Architecture

### Core Models
- **User**: Authentication with normalized emails and secure passwords
- **Session**: Session management with IP/user agent tracking  
- **LlmApiKey**: Encrypted storage for different LLM provider API keys

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
bin/rails test        # Run all tests
bin/rails test:system # Run system tests only
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
bundle exec rubocop   # Ruby linting
bundle exec brakeman  # Security scanning
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

## Testing Setup

Uses **Minitest** with parallel execution, **Capybara + Selenium** for system tests, and fixture-based test data. Tests are organized in standard Rails structure under `test/`.