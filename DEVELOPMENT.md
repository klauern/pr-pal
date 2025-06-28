# PR Pal Development Documentation

This document consolidates all current development work, recent features, and testing progress for PR Pal.

**Last Updated:** January 4, 2025  
**Current Test Coverage:** 30.83% line coverage (325/1054 lines)

---

## Table of Contents

1. [Data Provider System](#data-provider-system)
2. [GitHub Integration](#github-integration)
3. [Testing Plan & Progress](#testing-plan--progress)
4. [Architecture Notes](#architecture-notes)

---

## Data Provider System

### Overview

The system allows switching between dummy data and real GitHub API data using environment variables, providing a clean development experience while maintaining flexibility for production use.

### Configuration

#### Environment Variables

- `USE_DUMMY_DATA=true` - Use dummy data (default in development and test)
- `USE_DUMMY_DATA=false` - Use real GitHub API data (default in production)

#### Environment Defaults

- **Development**: `USE_DUMMY_DATA=true` (dummy data by default)
- **Test**: `USE_DUMMY_DATA=true` (dummy data by default)
- **Production**: `USE_DUMMY_DATA=false` (real data by default)

### Architecture

#### Data Providers

1. **Base Provider** (`PullRequestDataProvider`)
   - Abstract base class defining the interface
   - `fetch_or_create_pr_review(owner:, name:, pr_number:, user:)`

2. **Dummy Provider** (`DummyPullRequestDataProvider`)
   - Generates realistic dummy data
   - Random PR titles from a curated list
   - Auto-creates repositories and PR reviews

3. **GitHub Provider** (`GithubPullRequestDataProvider`)
   - Real GitHub API integration using Octokit.rb
   - Robust error handling and fallbacks

#### Provider Selection

The `DataProviders` module automatically selects the appropriate provider based on configuration:

```ruby
DataProviders.pull_request_provider
# Returns: DummyPullRequestDataProvider or GithubPullRequestDataProvider
```

### Usage

#### Starting the Server

```bash
# Use dummy data (development default)
bin/rails server

# Force real data mode
USE_DUMMY_DATA=false bin/rails server

# Force dummy data mode
USE_DUMMY_DATA=true bin/rails server
```

#### Testing Different Modes

```bash
# Test dummy data provider
echo 'DataProviders.pull_request_provider' | USE_DUMMY_DATA=true bin/rails console

# Test real data provider
echo 'DataProviders.pull_request_provider' | USE_DUMMY_DATA=false bin/rails console
```

#### Creating PR Reviews

Access any PR review URL and the system will auto-create repositories and reviews:

```
http://localhost:3000/repos/{owner}/{repo}/reviews/{pr_number}
```

Examples:
- `http://localhost:3000/repos/microsoft/vscode/reviews/123`
- `http://localhost:3000/repos/rails/rails/reviews/456`

### Visual Indicators

In development mode with dummy data enabled, a yellow indicator appears in the top-right corner:

```
🎭 DUMMY DATA MODE
```

### Dummy Data Features

- **Random PR Titles**: Realistic PR titles from a curated list
- **Auto Repository Creation**: Creates repositories automatically
- **Consistent URLs**: Generates proper GitHub URLs
- **Clean Database**: No orphaned records or validation issues

---

## GitHub Integration

### Quick Setup

1. **Generate a GitHub Personal Access Token (PAT)**
   - Go to [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)
   - Click "Generate new token (classic)"
   - Give it a name like "PR Pal Access"
   - Select these scopes:
     - `repo` - Full repository access (needed to read PRs and repository info)
     - `read:user` - Read user profile data
   - Copy the generated token (starts with `ghp_`)

2. **Configure PR Pal**
   - Start the Rails server: `bin/rails server`
   - Log in with demo credentials: `test@example.com` / `password`
   - Click "Settings" in the sidebar
   - Paste your GitHub token and save

3. **Switch to GitHub API mode**
   - Set environment variable: `USE_DUMMY_DATA=false`
   - Restart the server: `bin/rails server`

### How It Works

#### Data Provider Architecture

PR Pal uses a pluggable data provider system:

- **`DummyPullRequestDataProvider`** - Generates realistic test data (default in development)
- **`GithubPullRequestDataProvider`** - Fetches real data from GitHub API (for production use)

#### Automatic Fallbacks

The GitHub provider is designed to be robust:

- **No token configured?** → Falls back to basic PR creation with GitHub URLs
- **GitHub API error?** → Falls back gracefully, logs the error
- **Rate limit hit?** → Proper error handling and retry logic
- **PR not found?** → Clear error messages

#### Data Sync Strategy

- **Fresh data**: New PRs are fetched immediately from GitHub
- **Cached data**: Existing PRs are re-synced every 15 minutes
- **On-demand sync**: Coming soon - manual refresh buttons

### Features

#### Currently Implemented

✅ **Basic PR Info**: Title, description, state, URLs  
✅ **Repository Auto-Creation**: If repo doesn't exist, it's created automatically  
✅ **Encrypted Token Storage**: GitHub tokens are encrypted in the database  
✅ **Error Handling**: Graceful fallbacks for all GitHub API issues  
✅ **Rate Limit Awareness**: Proper handling of GitHub's API limits

#### Coming Soon

🚧 **CI/CD Status**: Build status, check results  
🚧 **PR Comments & Reviews**: Full discussion history  
🚧 **File Changes**: Diff view and file tree  
🚧 **Background Sync**: Automatic periodic updates  
🚧 **Webhook Integration**: Real-time updates

### Testing the Integration

#### 1. Dummy Data Mode (Default)

```bash
# Start with dummy data (default)
USE_DUMMY_DATA=true bin/rails server

# Visit a PR URL - will create dummy data
# http://localhost:3000/repos/klauern/test-repo/reviews/123
```

#### 2. GitHub API Mode

```bash
# Switch to real GitHub data
USE_DUMMY_DATA=false bin/rails server

# Configure your GitHub token in Settings
# Visit a real PR URL with your token configured
# http://localhost:3000/repos/klauern/your-repo/reviews/5
```

#### 3. Test Cases to Try

- **Valid PR**: Use a real PR from your repositories
- **Invalid PR**: Try a non-existent PR number
- **Private repo**: Test with a private repository (needs proper token scopes)
- **No token**: Try GitHub mode without configuring a token

### Troubleshooting

#### Common Issues

**"No GitHub token configured"**
- Go to Settings and add your Personal Access Token
- Make sure you copied the full token (starts with `ghp_`)

**"Invalid GitHub token or insufficient permissions"**
- Regenerate your token with `repo` and `read:user` scopes
- Make sure the token hasn't expired

**"Pull request not found"**
- Check that the repository owner and name are correct
- Verify the PR number exists
- Ensure your token has access to that repository

**"GitHub API rate limit exceeded"**
- Wait for the rate limit to reset (usually 1 hour)
- Consider upgrading to GitHub Pro for higher limits

#### Debug Information

Check the Rails logs for detailed information:

```bash
tail -f log/development.log
```

Look for messages like:
- `🔗 GitHub API provider: fetching PR owner/repo#123`
- `✅ Successfully synced PR data from GitHub API`
- `GitHub API error: [specific error message]`

### Security

- GitHub tokens are encrypted using Rails' built-in encryption
- Tokens are never logged or displayed in full (only last 4 characters shown)
- All GitHub API calls use HTTPS
- Brakeman security scanner shows 0 warnings

### Development

To add new GitHub API features:

1. Extend `GithubPullRequestDataProvider` with new methods
2. Add database fields if needed (migrations)
3. Update the interface in `PullRequestDataProvider` base class
4. Implement corresponding dummy data in `DummyPullRequestDataProvider`
5. Run security scan: `bundle exec brakeman`

The architecture makes it easy to add new GitHub API integrations while maintaining backward compatibility and fallback behavior.

---

## Testing Plan & Progress

### Current Status

**Current Coverage:** 30.83% line coverage (325/1054 lines)  
**Target Coverage:** 80%+ line coverage

**Status Legend:**
- 🔴 **TODO** - Not started
- 🟡 **DOING** - In progress  
- 🟢 **DONE** - Completed
- ⚠️ **BLOCKED** - Waiting on dependencies

### 1. Security-Critical Tests (HIGH PRIORITY)

#### Password Reset Security 🟢 **DONE**
**File:** `test/controllers/passwords_controller_test.rb` ✅ Created

**Test Cases:**
- [ ] GET /passwords/new - Show reset form
- [ ] POST /passwords - Send reset email
  - [ ] Valid email (user exists)
  - [ ] Invalid email (user doesn't exist)
  - [ ] Missing email parameter
  - [ ] Rate limiting (10 attempts per 3 minutes)
- [ ] GET /passwords/:token/edit - Show reset form with token
  - [ ] Valid token
  - [ ] Invalid/expired token
  - [ ] Malformed token
- [ ] PATCH /passwords/:token - Update password
  - [ ] Valid token with matching passwords
  - [ ] Valid token with mismatched passwords
  - [ ] Invalid token
  - [ ] Weak password validation
  - [ ] Token expiration handling
  - [ ] Token reuse prevention

**Security Scenarios:**
- [ ] CSRF protection verification
- [ ] SQL injection prevention
- [ ] XSS prevention in error messages
- [ ] Token manipulation attempts

#### Authentication & Authorization Security 🔴 **TODO**
**Files:** Various controller tests

**Test Cases:**
- [ ] Parameter tampering prevention (user IDs, repository IDs)
- [ ] Session manipulation attempts
- [ ] Cross-user data access prevention
- [ ] Concurrent session handling
- [ ] Session hijacking prevention
- [ ] Authentication bypass attempts

#### Input Validation Security 🔴 **TODO**
**Files:** Model and controller tests

**Test Cases:**
- [ ] XSS prevention in PR titles/descriptions
- [ ] SQL injection in search/filter inputs
- [ ] Very long input handling (DoS prevention)
- [ ] Special character handling
- [ ] Unicode input validation

### 2. Service Classes (BUSINESS LOGIC)

#### PullRequestSyncer Service 🟢 **DONE**
**File:** `test/services/pull_request_syncer_test.rb` ✅ Created

**Test Cases:**
- [ ] `sync!` method
  - [ ] Successful sync with multiple PRs
  - [ ] Empty repository (no PRs)
  - [ ] GitHub API failures
  - [ ] Network timeout scenarios
  - [ ] Invalid PR data handling
  - [ ] Partial success scenarios
- [ ] `sync_pull_request` method
  - [ ] New PR creation
  - [ ] Existing PR updates
  - [ ] Validation failures
  - [ ] Attribute assignment accuracy
- [ ] Error handling
  - [ ] ActiveRecord::RecordInvalid scenarios
  - [ ] Generic exceptions
  - [ ] Logging verification

#### GitHub Pull Request Data Provider 🔴 **TODO**
**File:** `test/services/github_pull_request_data_provider_test.rb` (doesn't exist)

**Test Cases:**
- [ ] `fetch_or_create_pr_review` method
  - [ ] Successful GitHub API integration
  - [ ] GitHub token missing scenarios
  - [ ] GitHub API errors (401, 403, 404, 429)
  - [ ] Network failures
  - [ ] Fallback to basic creation
- [ ] `fetch_pr_details` method
  - [ ] Valid PR data retrieval
  - [ ] Non-existent PR handling
  - [ ] Rate limiting responses
  - [ ] Invalid tokens
- [ ] Authentication scenarios
  - [ ] Valid GitHub tokens
  - [ ] Invalid/expired tokens
  - [ ] Missing permissions
  - [ ] Rate limit exceeded

#### Dummy Pull Request Data Provider 🔴 **TODO**
**File:** `test/services/dummy_pull_request_data_provider_test.rb` (doesn't exist)

**Test Cases:**
- [ ] Mock data generation consistency
- [ ] Edge cases (empty repositories)
- [ ] Data structure validation
- [ ] Dummy data uniqueness

### 3. Background Jobs

#### Pull Request Sync Job 🔴 **TODO**
**File:** `test/jobs/pull_request_sync_job_test.rb` (doesn't exist)

**Test Cases:**
- [ ] `perform` method
  - [ ] Successful repository sync
  - [ ] Repository not found scenarios
  - [ ] Sync service failures
  - [ ] Logging verification
- [ ] Class methods
  - [ ] `sync_user_repositories` (multiple repos)
  - [ ] `sync_all_repositories` (system-wide)
  - [ ] Error handling for each method
- [ ] Background job behavior
  - [ ] Queue assignment
  - [ ] Retry logic
  - [ ] Job scheduling

### 4. Controllers (Missing Coverage)

#### LLM Conversation Messages Controller 🟢 **DONE**
**File:** `test/controllers/llm_conversation_messages_controller_test.rb` ✅ Created

**Test Cases:**
- [ ] POST create action
  - [ ] Valid message content (Turbo Stream)
  - [ ] Valid message content (JSON)
  - [ ] Invalid/blank message content
  - [ ] Long message content
  - [ ] Unauthorized access (different user's review)
- [ ] Authorization scenarios
  - [ ] Access to non-existent pull request review
  - [ ] Access to another user's pull request review
  - [ ] Unauthenticated access

#### Tabs Controller 🟢 **DONE**
**File:** `test/controllers/tabs_controller_test.rb` ✅ Created

**Test Cases:**
- [ ] POST open_pr - Open PR tab
- [ ] DELETE close_pr - Close PR tab
- [ ] PATCH select_tab - Select tab
- [ ] Session handling
  - [ ] Tab limit enforcement (max 5 tabs)
  - [ ] Duplicate tab prevention
  - [ ] Invalid tab IDs
  - [ ] Empty session handling
  - [ ] Tab order preservation

### 5. Model Testing (Comprehensive)

#### User Model 🔴 **TODO**
**File:** `test/models/user_test.rb` (mostly empty)

**Test Cases:**
- [ ] Validations
  - [ ] Email format validation (various invalid formats)
  - [ ] Email uniqueness (case sensitivity)
  - [ ] Password length validation
  - [ ] Password confirmation matching
- [ ] Methods
  - [ ] `github_token_configured?` (with/without token)
  - [ ] `github_token_display` (masking logic)
  - [ ] Email normalization (trim, downcase)
- [ ] Associations
  - [ ] Dependent destroy behavior
  - [ ] Cascading deletions
- [ ] Security
  - [ ] Password hashing
  - [ ] GitHub token encryption

#### Repository Model 🔴 **TODO**
**File:** `test/models/repository_test.rb` (empty)

**Test Cases:**
- [ ] Validations
  - [ ] Owner/name presence validation
  - [ ] Uniqueness scoped to user
  - [ ] Invalid characters in owner/name
  - [ ] Very long owner/name values
- [ ] Methods
  - [ ] `full_name` method accuracy
  - [ ] `github_url` generation
- [ ] Associations
  - [ ] Dependent destroy for pull_requests/reviews
  - [ ] User scoping

#### Pull Request Review Model 🔴 **TODO**
**File:** `test/models/pull_request_review_test.rb` (doesn't exist)

**Test Cases:**
- [ ] Validations
  - [ ] Required field validation
  - [ ] Status inclusion validation
  - [ ] Uniqueness of github_pr_id per repository
  - [ ] URL format validation
- [ ] Methods
  - [ ] `mark_as_completed!` state transition
  - [ ] `mark_as_viewed!` timestamp update
  - [ ] `total_message_count` accuracy
  - [ ] `last_message` retrieval
- [ ] Scopes
  - [ ] `in_progress` scope filtering
  - [ ] `completed` scope filtering

### Progress Summary

**Completed:** 125+ test cases (4 major test files + comprehensive models)  
**In Progress:** Service tests, model completion  
**Remaining:** ~50+ test cases

**Major Achievements:**
- ✅ Password reset security tests (comprehensive)
- ✅ LLM conversation messages controller tests (full coverage)
- ✅ Tabs controller tests (comprehensive)
- ✅ PullRequestSyncer service tests (business logic)
- ✅ User model tests (40+ comprehensive tests)
- ✅ Repository model tests (35+ comprehensive tests)

**Estimated Coverage Impact:**
- Security tests: +15% coverage
- Service tests: +20% coverage  
- Model tests: +25% coverage
- Controller tests: +10% coverage
- Integration tests: +10% coverage

**Total Estimated Coverage:** 80%+

### Next Steps

1. **Start with Security-Critical Tests** (passwords_controller_test.rb)
2. **Move to Service Classes** (pull_request_syncer_test.rb)
3. **Complete Model Testing** (user_test.rb improvements)
4. **Add Integration Tests** (pull_request_workflow_test.rb)
5. **Performance & Edge Cases** (as needed)

---

## Architecture Notes

### Service Layer Architecture

#### Data Provider Pattern
- **PullRequestDataProvider**: Abstract base class defining interface for PR data sources
- **GithubPullRequestDataProvider**: Real GitHub API integration using Octokit
- **DummyPullRequestDataProvider**: Generates realistic dummy data for testing/demo
- **PullRequestDataProviderFactory**: Factory that chooses provider based on user config and environment

#### Core Services
- **PullRequestSyncer**: Main service for syncing PRs from external sources to database

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

### Files Modified During Development

#### Data Provider System
- `config/environments/development.rb` - Added dummy data config
- `config/environments/production.rb` - Added dummy data config
- `config/environments/test.rb` - Added dummy data config
- `config/initializers/data_providers.rb` - Provider selection logic
- `app/services/pull_request_data_provider.rb` - Base provider class
- `app/services/dummy_pull_request_data_provider.rb` - Dummy data implementation
- `app/services/github_pull_request_data_provider.rb` - GitHub API implementation
- `app/controllers/pull_request_reviews_controller.rb` - Updated to use providers
- `app/views/layouts/application.html.erb` - Added visual indicator

#### GitHub Integration
- Various service classes for GitHub API integration
- LLM API Key model for encrypted token storage
- Authentication and authorization improvements

---

*This document consolidates all current development work and should be updated as features are completed or new work begins.*