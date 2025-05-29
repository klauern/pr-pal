# GitHub Integration Setup

PR Pal now supports real GitHub API integration using Octokit.rb! This allows you to fetch real pull request data from GitHub repositories.

## Quick Setup

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

## How It Works

### Data Provider Architecture

PR Pal uses a pluggable data provider system:

- **`DummyPullRequestDataProvider`** - Generates realistic test data (default in development)
- **`GithubPullRequestDataProvider`** - Fetches real data from GitHub API (for production use)

### Automatic Fallbacks

The GitHub provider is designed to be robust:

- **No token configured?** → Falls back to basic PR creation with GitHub URLs
- **GitHub API error?** → Falls back gracefully, logs the error
- **Rate limit hit?** → Proper error handling and retry logic
- **PR not found?** → Clear error messages

### Data Sync Strategy

- **Fresh data**: New PRs are fetched immediately from GitHub
- **Cached data**: Existing PRs are re-synced every 15 minutes
- **On-demand sync**: Coming soon - manual refresh buttons

## Features

### Currently Implemented

✅ **Basic PR Info**: Title, description, state, URLs
✅ **Repository Auto-Creation**: If repo doesn't exist, it's created automatically
✅ **Encrypted Token Storage**: GitHub tokens are encrypted in the database
✅ **Error Handling**: Graceful fallbacks for all GitHub API issues
✅ **Rate Limit Awareness**: Proper handling of GitHub's API limits

### Coming Soon

🚧 **CI/CD Status**: Build status, check results
🚧 **PR Comments & Reviews**: Full discussion history
🚧 **File Changes**: Diff view and file tree
🚧 **Background Sync**: Automatic periodic updates
🚧 **Webhook Integration**: Real-time updates

## Testing the Integration

### 1. Dummy Data Mode (Default)

```bash
# Start with dummy data (default)
USE_DUMMY_DATA=true bin/rails server

# Visit a PR URL - will create dummy data
# http://localhost:3000/repos/klauern/test-repo/reviews/123
```

### 2. GitHub API Mode

```bash
# Switch to real GitHub data
USE_DUMMY_DATA=false bin/rails server

# Configure your GitHub token in Settings
# Visit a real PR URL with your token configured
# http://localhost:3000/repos/klauern/your-repo/reviews/5
```

### 3. Test Cases to Try

- **Valid PR**: Use a real PR from your repositories
- **Invalid PR**: Try a non-existent PR number
- **Private repo**: Test with a private repository (needs proper token scopes)
- **No token**: Try GitHub mode without configuring a token

## Troubleshooting

### Common Issues

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

### Debug Information

Check the Rails logs for detailed information:

```bash
tail -f log/development.log
```

Look for messages like:

- `🔗 GitHub API provider: fetching PR owner/repo#123`
- `✅ Successfully synced PR data from GitHub API`
- `GitHub API error: [specific error message]`

## Security

- GitHub tokens are encrypted using Rails' built-in encryption
- Tokens are never logged or displayed in full (only last 4 characters shown)
- All GitHub API calls use HTTPS
- Brakeman security scanner shows 0 warnings

## Development

To add new GitHub API features:

1. Extend `GithubPullRequestDataProvider` with new methods
2. Add database fields if needed (migrations)
3. Update the interface in `PullRequestDataProvider` base class
4. Implement corresponding dummy data in `DummyPullRequestDataProvider`
5. Run security scan: `bundle exec brakeman`

The architecture makes it easy to add new GitHub API integrations while maintaining backward compatibility and fallback behavior.
