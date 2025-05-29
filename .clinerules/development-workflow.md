## Brief overview

Development workflow guidelines for Rails applications, emphasizing test-first completion verification, security validation, and robust error handling patterns.

## Testing requirements

- Always run `bin/rails test` before marking any task as complete
- Fix any failing tests before attempting completion
- Add appropriate test coverage for new features, especially controller actions
- Use proper authentication setup in controller tests
- Handle encryption and credentials properly in test environment
- Verify security scan passes with `bundle exec brakeman`

## GitHub API integration patterns

- Use Octokit.rb for GitHub API integration with proper error handling
- Implement fallback mechanisms for API failures (rate limits, network issues, invalid tokens)
- Store sensitive tokens using Rails encryption (`encrypts :field_name`)
- Skip encryption in test environment to avoid credential configuration complexity
- Provide clear user guidance for GitHub Personal Access Token setup
- Implement robust provider pattern for switching between dummy and real data sources

## Error handling and resilience

- Always implement graceful fallbacks when external APIs fail
- Log meaningful error messages with appropriate log levels
- Use custom exception classes for different error types (AuthenticationError, NotFoundError, RateLimitError)
- Provide helpful user-facing error messages and setup instructions
- Test both success and failure scenarios

## Security practices

- Run Brakeman security scanner before completion
- Encrypt sensitive data like API tokens
- Never log or display full tokens (show only last 4 characters)
- Use proper authentication checks in controllers
- Follow Rails security best practices for parameter filtering

## Documentation standards

- Create comprehensive setup guides for complex integrations
- Include troubleshooting sections with common issues and solutions
- Provide clear examples of usage patterns
- Document both development and production configuration steps
- Include security considerations and best practices

## Architecture decisions

- Use provider pattern for pluggable data sources
- Implement environment-based configuration switching
- Maintain backward compatibility when adding new features
- Design for gradual feature rollout and testing
- Keep clean separation between dummy and production data flows
