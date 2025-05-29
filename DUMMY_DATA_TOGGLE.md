# Dummy/Real Data Toggle System

This document describes the dummy/real data toggle system implemented for PR Pal.

## Overview

The system allows switching between dummy data and real GitHub API data using environment variables, providing a clean development experience while maintaining flexibility for production use.

## Configuration

### Environment Variables

- `USE_DUMMY_DATA=true` - Use dummy data (default in development and test)
- `USE_DUMMY_DATA=false` - Use real GitHub API data (default in production)

### Environment Defaults

- **Development**: `USE_DUMMY_DATA=true` (dummy data by default)
- **Test**: `USE_DUMMY_DATA=true` (dummy data by default)
- **Production**: `USE_DUMMY_DATA=false` (real data by default)

## Architecture

### Data Providers

1. **Base Provider** (`PullRequestDataProvider`)
   - Abstract base class defining the interface
   - `fetch_or_create_pr_review(owner:, name:, pr_number:, user:)`

2. **Dummy Provider** (`DummyPullRequestDataProvider`)
   - Generates realistic dummy data
   - Random PR titles from a curated list
   - Auto-creates repositories and PR reviews

3. **GitHub Provider** (`GithubPullRequestDataProvider`)
   - Skeleton for future GitHub API integration
   - Currently falls back to basic creation (no API calls yet)

### Provider Selection

The `DataProviders` module automatically selects the appropriate provider based on configuration:

```ruby
DataProviders.pull_request_provider
# Returns: DummyPullRequestDataProvider or GithubPullRequestDataProvider
```

## Usage

### Starting the Server

```bash
# Use dummy data (development default)
rails server

# Force real data mode
USE_DUMMY_DATA=false rails server

# Force dummy data mode
USE_DUMMY_DATA=true rails server
```

### Testing Different Modes

```bash
# Test dummy data provider
echo 'DataProviders.pull_request_provider' | USE_DUMMY_DATA=true rails console

# Test real data provider
echo 'DataProviders.pull_request_provider' | USE_DUMMY_DATA=false rails console
```

### Creating PR Reviews

Access any PR review URL and the system will auto-create repositories and reviews:

```
http://localhost:3000/repos/{owner}/{repo}/reviews/{pr_number}
```

Examples:

- `http://localhost:3000/repos/microsoft/vscode/reviews/123`
- `http://localhost:3000/repos/rails/rails/reviews/456`

## Visual Indicators

In development mode with dummy data enabled, a yellow indicator appears in the top-right corner:

```
🎭 DUMMY DATA MODE
```

## Dummy Data Features

- **Random PR Titles**: Realistic PR titles from a curated list
- **Auto Repository Creation**: Creates repositories automatically
- **Consistent URLs**: Generates proper GitHub URLs
- **Clean Database**: No orphaned records or validation issues

## Future Enhancements

1. **GitHub API Integration**: Complete the `GithubPullRequestDataProvider`
2. **Rich Dummy Data**: Add FactoryBot and Faker for more realistic data
3. **Background Sync**: Implement data synchronization jobs
4. **API Rate Limiting**: Handle GitHub API rate limits gracefully

## Files Modified

- `config/environments/development.rb` - Added dummy data config
- `config/environments/production.rb` - Added dummy data config
- `config/environments/test.rb` - Added dummy data config
- `config/initializers/data_providers.rb` - Provider selection logic
- `app/services/pull_request_data_provider.rb` - Base provider class
- `app/services/dummy_pull_request_data_provider.rb` - Dummy data implementation
- `app/services/github_pull_request_data_provider.rb` - GitHub API skeleton
- `app/controllers/pull_request_reviews_controller.rb` - Updated to use providers
- `app/views/layouts/application.html.erb` - Added visual indicator
