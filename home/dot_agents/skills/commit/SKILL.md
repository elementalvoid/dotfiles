---
name: commit
description: Create git commit(s) using Conventional Commits. Use when user says "commit", "commit my changes", "save my work", "checkpoint", "stage and commit", "amend the last commit", "amend that", "wip commit", or wants to commit and push.
allowed-tools: Bash(git add:*),Bash(git rm:*), Bash(git status:*), Bash(git commit:*), Bash(git log:*), Bash(git branch:*), Bash(git push:*), Bash(git diff:*), Bash(git rev-parse:*), AskUserQuestion
agent: Explore
---

## Context

- Current git status: !`git status`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`
- [Conventional Commits specification](conventional-commits-reference.md)

## What This Command Does

1. Parses flags from `$ARGUMENTS`
2. Uses current git status context to understand which files are staged
3. Stages files (unless `--no-stage` or `--amend` is passed)
4. Performs a `git diff` to understand what changes are being committed
5. Analyzes the diff to determine if multiple distinct logical changes are present
6. If multiple distinct changes are detected, suggests breaking the commit into multiple smaller commits
7. For each commit (or the single commit if not split), creates a commit message using Conventional Commits specification
8. Optionally pushes after committing based on flags

## Step 0 — Parse Arguments

Parse `$ARGUMENTS` for optional flags before doing anything else:

- `--help` / `-h` → print usage and exit
- `--push` / `-p` → push to remote after committing
- `--no-push` → skip push even if a default push behavior is configured
- `--amend` / `-a` → amend the last commit instead of creating a new one
- `--no-stage` → only commit what is already staged; skip staging logic entirely
- `--all` / `-A` → force-stage all changes without prompting
- `--wip` → create a quick `chore: wip` checkpoint commit with no analysis

**If `--help` / `-h` is passed**, print the following and stop — do not run any git commands:

```text
Usage: /commit [options]

Options:
  -h, --help       Show this help message
  -p, --push       Push to remote after committing
      --no-push    Skip push (overrides --push)
  -a, --amend      Amend the last commit instead of creating a new one
      --no-stage   Only commit already-staged files; skip staging logic
  -A, --all        Stage all changes without prompting
      --wip        Create a quick chore: wip checkpoint commit

Examples:
  /commit
  /commit --push
  /commit --amend
  /commit --wip --push
  /commit --all --push
  /commit --no-stage
```

**Branch safety check:** if current branch is `main` or `master`, stop and tell the user they must be on a feature branch before committing (applies to all flows including `--wip`).

## Step 1 — Stage Files

**Skip this step entirely if `--no-stage` is passed** (applies to both normal and `--amend` flows).

- If `--all` / `-A` is passed: run `git add -A` without prompting.
- If specific files are already staged and `--all` was not passed: use `AskUserQuestion` to ask the user how to proceed (e.g., "You have 3 files staged. Do you want to commit these as-is, or let the agent automatically stage all changes?")
- If 0 files are staged: automatically add all modified and new files with `git add -A`.

> **When used with `--amend`:** staging works the same way — use `--no-stage` to amend using only what is already staged, `--all` to stage everything first, or let the agent prompt as usual.

## Step 2 — WIP Fast Path

**Only runs if `--wip` is passed.**

1. Run `git add -A` (stage everything).
2. Commit immediately: `git commit -m "chore: wip"`
3. Skip to **Step 6 — Push** (respecting `--push` / `--no-push`).

## Step 3 — Amend Flow

**Only runs if `--amend` is passed.**

1. Run `git diff --cached` to show what is staged for the amended commit.
2. Re-synthesize a commit message by combining:
   - The existing last commit message (`git log -1 --pretty=%B`)
   - The updated diff
3. Show the user the proposed amended message and confirm with `AskUserQuestion` before proceeding.
4. Run `git commit --amend -m "<message>"`.
5. Skip to **Step 6 — Push**.

## Step 4 — Analyze Diff and Split

Run `git diff --cached` to understand what is staged.

Analyze the diff to determine if multiple distinct logical changes are present. Consider splitting based on:

1. **Different concerns**: changes to unrelated parts of the codebase
2. **Different types of changes**: mixing features, fixes, refactoring, etc.
3. **File patterns**: changes to different types of files (e.g., source code vs. documentation)
4. **Logical grouping**: changes that would be easier to understand or review separately
5. **Size**: very large changes that would be clearer if broken down

If multiple distinct changes are detected, suggest breaking into multiple smaller commits and confirm with the user.

## Step 5 — Compose and Commit

For each commit (or the single commit):

**Jira Issue Key:**
- If the branch name has the scheme `PROJ-123/branch-name` or `proj-58/feat/branch-name`, extract the issue key (e.g. `PROJ-123` or `PROJ-58`).
- Otherwise use `AskUserQuestion` to ask the user for a Jira issue key (may be left blank).

**Commit message (Conventional Commits):**
- Derive the type from the diff: `feat` / `fix` / `chore` / `refactor` / `docs` / `ci` / `test`
- Concise imperative subject line ≤ 72 characters
- Optional body if the change warrants explanation
- Footer: `Refs: PROJ-123` (if a Jira key was found)

Run `git commit -m "<message>"`.

## Step 6 — Push

**Skip this step if `--no-push` is passed.**
**Only run this step if `--push` / `-p` is passed** (or `--wip --push`, etc.).

Detect whether the branch has an upstream:

```bash
git rev-parse --abbrev-ref @{u} 2>/dev/null
```

- If upstream exists: run `git push`.
- If no upstream: run `git push -u origin $(git branch --show-current)`.
- If push fails (non-fast-forward or other error): report the error and stop — do not force-push.

## Best Practices

- **Atomic commits**: each commit should contain related changes that serve a single purpose
- **Present tense, imperative mood**: write commit messages as commands (e.g., "add feature" not "added feature")
- **Concise first line**: keep the first line under 72 characters
- **Never commit to `main`/`master`**: always use a feature branch
