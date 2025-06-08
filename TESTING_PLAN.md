# PR Pal Testing Plan & Progress Tracker

**Current Coverage:** 30.83% line coverage (325/1054 lines)  
**Target Coverage:** 80%+ line coverage  
**Last Updated:** January 4, 2025

## Overview

This document tracks the comprehensive testing plan for PR Pal to improve code coverage, security, and robustness. Each section includes specific test cases and progress tracking.

**Status Legend:**
- 🔴 **TODO** - Not started
- 🟡 **DOING** - In progress  
- 🟢 **DONE** - Completed
- ⚠️ **BLOCKED** - Waiting on dependencies

---

## 1. Security-Critical Tests (HIGH PRIORITY)

### Password Reset Security 🟢 **DONE**
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

### Authentication & Authorization Security 🔴 **TODO**
**Files:** Various controller tests

**Test Cases:**
- [ ] Parameter tampering prevention (user IDs, repository IDs)
- [ ] Session manipulation attempts
- [ ] Cross-user data access prevention
- [ ] Concurrent session handling
- [ ] Session hijacking prevention
- [ ] Authentication bypass attempts

### Input Validation Security 🔴 **TODO**
**Files:** Model and controller tests

**Test Cases:**
- [ ] XSS prevention in PR titles/descriptions
- [ ] SQL injection in search/filter inputs
- [ ] Very long input handling (DoS prevention)
- [ ] Special character handling
- [ ] Unicode input validation

---

## 2. Service Classes (BUSINESS LOGIC)

### PullRequestSyncer Service 🟢 **DONE**
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

### GitHub Pull Request Data Provider 🔴 **TODO**
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

### Dummy Pull Request Data Provider 🔴 **TODO**
**File:** `test/services/dummy_pull_request_data_provider_test.rb` (doesn't exist)

**Test Cases:**
- [ ] Mock data generation consistency
- [ ] Edge cases (empty repositories)
- [ ] Data structure validation
- [ ] Dummy data uniqueness

### Pull Request Data Provider Factory 🔴 **TODO**
**File:** `test/services/pull_request_data_provider_test.rb` (doesn't exist)

**Test Cases:**
- [ ] Provider selection logic
  - [ ] User with GitHub token → GitHub provider
  - [ ] User without token → Dummy provider
  - [ ] Invalid user scenarios

---

## 3. Background Jobs

### Pull Request Sync Job 🔴 **TODO**
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

---

## 4. Controllers (Missing Coverage)

### LLM Conversation Messages Controller 🟢 **DONE**
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

### Tabs Controller 🟢 **DONE**
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

### Enhanced Controller Tests 🔴 **TODO**
**Files:** Existing controller test files

**Repositories Controller:**
- [ ] Access to other user's repositories
- [ ] Repository creation with duplicate names
- [ ] Repository deletion cascade effects
- [ ] Invalid repository parameters
- [ ] Invalid owner/name formats

**Pull Request Reviews Controller:**
- [ ] Concurrent access to same PR
- [ ] Very long PR titles/URLs
- [ ] Invalid GitHub PR IDs
- [ ] Network failures during GitHub API calls
- [ ] Rate limiting scenarios

---

## 5. Model Testing (Comprehensive)

### User Model 🔴 **TODO**
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

### Repository Model 🔴 **TODO**
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

### Pull Request Review Model 🔴 **TODO**
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

### LLM Conversation Message Model 🔴 **TODO**
**File:** `test/models/llm_conversation_message_test.rb` (doesn't exist)

**Test Cases:**
- [ ] Validations
  - [ ] Sender presence validation
  - [ ] Content presence and length validation
  - [ ] Order uniqueness within review
  - [ ] Order numbering logic
- [ ] Methods
  - [ ] `from_user?` logic
  - [ ] `from_llm?` logic
  - [ ] Automatic order assignment
  - [ ] Timestamp setting
- [ ] Scopes
  - [ ] `ordered` scope accuracy
  - [ ] `by_user`/`by_llm` filtering

### Session Model 🔴 **TODO**
**File:** `test/models/session_test.rb` (doesn't exist)

**Test Cases:**
- [ ] Validations
  - [ ] User association validation
  - [ ] IP address format validation
  - [ ] User agent length validation
- [ ] Security
  - [ ] Session token generation
  - [ ] Session expiration handling
  - [ ] IP address tracking accuracy

### Pull Request Model 🔴 **TODO**
**File:** `test/models/pull_request_test.rb` (doesn't exist)

**Test Cases:**
- [ ] Validations
  - [ ] Required field validation
  - [ ] Uniqueness constraints
  - [ ] URL format validation
- [ ] Methods
  - [ ] State checking methods (`open?`, `closed?`, `merged?`)
  - [ ] `number` alias method
- [ ] Scopes
  - [ ] State-based scopes
  - [ ] Ordering scopes

### Enhanced LLM API Key Model 🔴 **TODO**
**File:** `test/models/llm_api_key_test.rb` (minimal tests)

**Additional Test Cases:**
- [ ] Edge cases for uniqueness validation
  - [ ] Case sensitivity in provider names
  - [ ] Unicode/special characters
  - [ ] Very long provider names
- [ ] Security tests
  - [ ] API key encryption
  - [ ] API key length validation
  - [ ] API key format validation

---

## 6. Helper Testing

### Application Helper 🔴 **TODO**
**File:** `test/helpers/application_helper_test.rb` (doesn't exist)

**Test Cases:**
- [ ] `safe_pr_link` method
  - [ ] Valid GitHub URLs
  - [ ] Invalid URLs (XSS prevention)
  - [ ] Empty/nil URLs
  - [ ] Non-GitHub URLs
  - [ ] HTML escaping verification
- [ ] `safe_pr_url` method
  - [ ] URL validation logic
  - [ ] Security filtering
  - [ ] Edge cases (malformed URLs)

---

## 7. Integration Testing

### Pull Request Workflow Integration 🔴 **TODO**
**File:** `test/integration/pull_request_workflow_test.rb` (doesn't exist)

**Test Cases:**
- [ ] End-to-end PR review workflow
  - [ ] Repository creation → PR sync → Review creation → Message exchange
  - [ ] Multiple users working on same repository
  - [ ] Concurrent access scenarios
  - [ ] Data consistency across workflow
- [ ] GitHub integration flow
  - [ ] Token configuration → Repository sync → PR fetching
  - [ ] Token expiration during workflow
  - [ ] API rate limiting handling

### Authentication Flow Integration 🔴 **TODO**
**File:** `test/integration/authentication_complete_flow_test.rb` (doesn't exist)

**Test Cases:**
- [ ] Complete auth flow edge cases
  - [ ] Session expiration during long operations
  - [ ] Concurrent login attempts
  - [ ] Session hijacking prevention
  - [ ] Cross-user data access attempts
- [ ] Password reset complete flow
  - [ ] Reset request → Email delivery → Token validation → Password update
  - [ ] Multiple reset attempts
  - [ ] Token manipulation attempts

### Error Recovery Integration 🔴 **TODO**
**File:** `test/integration/error_recovery_test.rb` (doesn't exist)

**Test Cases:**
- [ ] System failure scenarios
  - [ ] Database connection failures
  - [ ] GitHub API outages
  - [ ] Background job failures
  - [ ] Partial data corruption recovery

---

## 8. Performance & Edge Cases

### Performance Testing 🔴 **TODO**
**File:** `test/performance/` (directory doesn't exist)

**Test Cases:**
- [ ] Load testing scenarios
  - [ ] Large number of repositories per user
  - [ ] High-frequency GitHub API calls
  - [ ] Database query optimization
  - [ ] Memory usage with large datasets
- [ ] Background job performance
  - [ ] Job queue buildup scenarios
  - [ ] Failed job retry behavior
  - [ ] Job scheduling optimization

### Edge Case Testing 🔴 **TODO**
**Files:** Various test files

**Test Cases:**
- [ ] Data limits
  - [ ] Maximum message length
  - [ ] Maximum repository count per user
  - [ ] Maximum open tabs
  - [ ] Large dataset pagination
- [ ] Concurrency
  - [ ] Simultaneous PR reviews
  - [ ] Concurrent GitHub syncs
  - [ ] Race conditions in session management

---

## 9. Test Infrastructure Improvements

### Test Setup & Fixtures 🔴 **TODO**
**Test Cases:**
- [ ] Factory methods for complex object creation
- [ ] Test data consistency
- [ ] Performance test data generators
- [ ] Test database cleanup strategies

### Test Organization 🔴 **TODO**
**Test Cases:**
- [ ] Shared test helpers
- [ ] Common assertion helpers
- [ ] Test categories and tagging
- [ ] Parallel test execution optimization

---

## Progress Summary

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

---

## Next Steps

1. **Start with Security-Critical Tests** (passwords_controller_test.rb)
2. **Move to Service Classes** (pull_request_syncer_test.rb)
3. **Complete Model Testing** (user_test.rb improvements)
4. **Add Integration Tests** (pull_request_workflow_test.rb)
5. **Performance & Edge Cases** (as needed)

---

## Notes & Dependencies

- Some tests may require VCR or similar for external API mocking
- Performance tests may need separate test database
- Security tests should be reviewed by security-focused developers
- Integration tests may require specific test data setup

---

*This document should be updated as tests are completed. Mark sections as 🟡 DOING when starting work, and 🟢 DONE when completed with notes about any important findings or changes needed.*