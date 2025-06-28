---
allowed-tools: Bash(gh:*), Bash(git:*), Bash(bundle:*)
description: fix pull request lint errors
---

Using the `gh` CLI, review the pull request for lint errors and fix them.

Once done and passing, create a git commit with the fix, and push the changes to the remote branch. The pull request will automatically update.  Run `gh pr checks` periodically to see if the pull request is passing. You will need to wait a few seconds for the checks to start.
