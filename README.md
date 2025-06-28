# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## CLI Usage

A Thor-based CLI is available for interacting with pull request reviews from the command line. Run commands via `bin/prpal`.

Example commands:

```
bin/prpal reviews list           # List all pull request reviews
bin/prpal reviews show <id>      # Show details for a review
```

The CLI loads the Rails environment so it has access to all models and services.

