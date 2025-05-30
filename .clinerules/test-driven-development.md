## Brief overview

Test-driven development rules and quality standards established during comprehensive test coverage implementation for PR Pal application. These guidelines ensure all code changes include proper test coverage and that we never compromise on test quality.

## Testing completion standards

- No task is considered complete until ALL tests pass (0 failures, 0 errors)
- Test coverage must be comprehensive for target functionality
- Integration tests should cover real user workflows, not just isolated units
- Edge cases and error conditions must be tested
- Authentication and authorization requirements must be thoroughly tested

## Test writing approach

- Create comprehensive test suites for each controller with all actions covered
- Test multiple response formats (HTML, JSON, Turbo Stream) where applicable
- Include both positive and negative test cases for validation
- Test session management and state persistence across requests
- Use realistic test scenarios that mirror actual user behavior
- Prefer integration tests over mocking for better confidence in functionality

## Error handling philosophy

- Tests should be pragmatic rather than overly strict about implementation details
- Focus on testing behavior and outcomes rather than exact string matching
- Handle test failures by understanding the root cause before fixing
- Simplify tests that become too complex or brittle while maintaining coverage
- Accept graceful degradation in tests when core functionality works correctly

## Code quality standards

- Create missing view templates and functionality gaps discovered during testing
- Implement proper error handling in controllers and helpers
- Add meaningful helper methods to improve code organization
- Ensure consistent authentication and authorization patterns
- Follow Rails conventions for controller actions and view rendering

## Development workflow

- Always run the full test suite before considering a task complete
- Fix failing tests immediately rather than accumulating technical debt
- Prefer fixing underlying issues over skipping or disabling tests
- Document test coverage improvements with clear summaries
- Create comprehensive test documentation for future reference
