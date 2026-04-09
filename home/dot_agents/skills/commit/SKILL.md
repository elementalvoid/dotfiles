---
name: commit
description: Create git commit(s) using Conventional Commits specification.
allowed-tools: Bash(git add:*),Bash(git rm:*), Bash(git status:*), Bash(git commit:*), Bash(git log:*), Bash(git branch:--show-current)
agent: Explore
---

## Context

- Current git status: !`git status`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`
- [Conventional Commits specification](conventional-commits-reference.md)

## What This Command Does

1. Uses current git status context to understand which files are staged
2. If specific files are already staged, use the `AskUserQuestion` tool to ask the user how ot proceed (e.g., "You have 3 files staged. Do you want to commit these as is, or let the agent automatically commit all changes?")
3. If 0 files are staged, automatically adds all modified and new files with `git add`
4. Performs a `git diff` to understand what changes are being committed
5. Analyzes the diff to determine if multiple distinct logical changes are present
6. If multiple distinct changes are detected, suggests breaking the commit into multiple smaller commits
7. For each commit (or the single commit if not split), creates a commit message using Conventional Commits specification

## Best Practices for Commits

- **Jira Issue Keys**: Always include a Jira issue key in the footer of the commit message if available
  - If the branch name has the scheme `JIRA-123/branch-name` or `enp-58/feat/branch-name`, extract the issue key (e.g. `JIRA-123` or `ENP-58`)
  - Otherwise use the `AskUserQuestion` tool to ask the user for a Jira issue key
- **Branch naming**: Never commit to `main`/`master`; always use a feature branch.
  - If the current branch is the default (`main`/`master`) we _must_ create a new branch before committing.
  - The branch name should include a `reason` and optionally a Conventional Commit style intent: `fix/type-mismatch`, `chore/user-docs-update`
  - The branch name should include the Jira issue if available: `<jira-issue>/<reason>`
- **Atomic commits**: Each commit should contain related changes that serve a single purpose
- **Split large changes**: If changes touch multiple concerns, split them into separate commits
- **Present tense, imperative mood**: Write commit messages as commands (e.g., "add feature" not "added feature")
- **Concise first line**: Keep the first line under 72 characters

## Guidelines for Splitting Commits

When analyzing the diff, consider splitting commits based on these criteria:

1. **Different concerns**: Changes to unrelated parts of the codebase
2. **Different types of changes**: Mixing features, fixes, refactoring, etc.
3. **File patterns**: Changes to different types of files (e.g., source code vs documentation)
4. **Logical grouping**: Changes that would be easier to understand or review separately
5. **Size**: Very large changes that would be clearer if broken down
