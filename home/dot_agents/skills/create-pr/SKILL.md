---
name: create-pr
description: Create a GitHub PR using gh CLI, auto-filling the PR template with Jira issue, title, and body synthesized from commits and diff. Use when user says "open a PR", "create a pull request", "raise a PR", "submit for review", "ship this branch", or wants to merge their branch.
allowed-tools: Bash(git log:*), Bash(git branch:*), Bash(git diff:*), Bash(git push:*), Bash(git remote:*), Bash(gh pr create:*), Bash(gh pr view:*), Bash(gh repo view:*), Bash(find:*), Bash(cat:*), AskUserQuestion
agent: Explore
---

## Context

- Current branch: !`git branch --show-current`
- Commits since main: !`git log main..HEAD --oneline`
- Changed files: !`git diff main...HEAD --stat`

## What This Skill Does

1. Extracts Jira issue key and base branch from the current branch name
2. Discovers and loads the repo's PR template (if one exists)
3. Synthesizes a PR title and body from commits + diff, filling in the template
4. Shows the user a preview and collects any edits before creating
5. Pushes the branch if needed, then runs `gh pr create`
6. Reports the PR URL

## Step 1 — Parse Arguments and Branch

Parse `$ARGUMENTS` for optional flags:

- `--help` / `-h` → print usage and exit (do not create a PR)
- `--draft` / `-d` → create as draft PR
- `--reviewer <handle>` → add reviewer(s) (can repeat; accepts `@org/team` or `@user`)
- `--base <branch>` → override base branch (default: `main`)
- `--no-template` → skip PR template discovery
- `--big-threshold <n>` → override the changed-line count that triggers a diff breakdown (default: `400`)
- A bare Jira issue key like `ENP-123` → override auto-detected issue

**If `--help` / `-h` is passed**, print the following and stop — do not run any git or gh commands:

```text
Usage: /create-pr [options] [JIRA-KEY] ["PR title"]

Options:
  -h, --help              Show this help message
  -d, --draft             Open PR as a draft
  --reviewer <handle>     Add a reviewer (repeatable; @user or @org/team)
  --base <branch>         Set the base branch (default: main)
  --no-template           Skip PR template discovery
  --big-threshold <n>     Changed-line count that triggers a diff breakdown (default: 400)

Arguments:
  JIRA-KEY                Override the Jira issue key auto-detected from the branch name (e.g. ENP-123)
  "PR title"              Override the auto-generated PR title (wrap in quotes)

Examples:
  /create-pr
  /create-pr --draft
  /create-pr ENP-123
  /create-pr --reviewer @Org/team --base release/v2
  /create-pr ENP-99 "feat: my custom title"
```

**Extract Jira issue key from the branch name:**

- Pattern `PROJ-58/feat/branch-name` → `PROJ-58`
- Pattern `feat/PROJ-58-branch-name` → `PROJ-58`
- Pattern `fix/type-mismatch` (no issue) → ask the user: "What Jira issue key should be linked to this PR? (leave blank to skip)"

**Branch safety check:** if current branch is `main` or `master`, stop and tell the user they must be on a feature branch before opening a PR.

**Determine base branch:** use `--base` argument if provided, otherwise default to `main`. Verify it exists on the remote with `git remote show origin`.

## Step 2 — Discover PR Template

Search for a PR template in this order (stop at first match, unless `--no-template` was passed):

```bash
find . -maxdepth 3 \( \
  -name "PULL_REQUEST_TEMPLATE.md" \
  -o -path "./.github/PULL_REQUEST_TEMPLATE.md" \
  -o -path "./.github/PULL_REQUEST_TEMPLATE/*.md" \
\) -not -path "./.git/*" 2>/dev/null
```

- If **one template** is found: use it silently.
- If **multiple templates** are found: use `AskUserQuestion` to let the user pick.
- If **no template** is found: use this minimal fallback structure:

```markdown
## Summary

## Changes

## Testing
```

## Step 3 — Synthesize PR Title and Body

**Title:**

- Look at the commits since `main` (`git log main..HEAD --oneline`)
- Derive the Conventional Commit type from the commit messages (feat / fix / chore / refactor / docs / ci / test)
- If all commits share a single type, use that; if mixed, pick the most significant (feat > fix > refactor > chore)
- Compose a concise imperative title: `<type>: <what this PR does>` (≤72 chars)
- If `$ARGUMENTS` contains a quoted string, treat it as the title override

**Body — fill the template intelligently:**

- **Jira link placeholders** (e.g. `JIRA-TICKET`, `JIRA-123`): replace with the real issue key. Construct the link using the `$JIRA_URL` env var if set (e.g. `[PROJ-123]($JIRA_URL/browse/PROJ-123)`); if the env var is absent, render the key as plain text and append a `<!-- TODO: add Jira link -->` comment. If no issue key was found at all, leave the placeholder with a `<!-- TODO -->` note.
- **Checklist items (`- [ ] ...`)**: keep them as-is — do not check them off; they are for the author to action.
- **Prose sections** (Summary, Background, Changes, Deployment, etc.): synthesize content from the commit messages and diff stat. Be concise but genuinely useful — 2–5 sentences per section. Include:
  - _Why_: reason for the change (infer from commit messages and branch name)
  - _What_: high-level description of what changed (from diff stat)
  - _How_: brief approach summary if non-obvious
- Leave any section that can't be meaningfully inferred with a `<!-- TODO: fill in -->` comment rather than invented content.

**Formatting — do NOT hard-wrap prose:**

- **Each paragraph is a single line.** GitHub reflows prose to the available column width; hard-wrapping at ~72/80 columns produces awkward ragged breaks in the rendered PR view (especially in the narrow main column when the sidebar is visible).
- Use blank lines to separate paragraphs.
- **Hard newlines are fine** for: code fences, lists, tables, headings, and intentional line breaks (e.g. address blocks).
- Mental model: write Markdown the way it renders, not the way it reads in a terminal. If you wouldn't put a `\n` in a `<p>` tag in HTML, don't put one in the source either.
- This applies whether you're using `gh pr create --body-file` or piping a heredoc — the file/string itself should not contain mid-paragraph wraps.

## Step 3.5 — Assess PR Size and Add a Diff Breakdown if Big

Determine whether this PR counts as **big**:

```bash
git diff <base>...HEAD --shortstat
git diff <base>...HEAD --stat
```

- **Big** if insertions + deletions from `--shortstat` exceed `400` (or `--big-threshold` if given), OR the diff touches more than 15 files.
- If not big, skip this step entirely — do not add a breakdown to a small PR.

If big, run the categorization workflow in `references/diff-breakdown.md` against the same base branch:

1. Fetch `git diff <base>...HEAD --numstat` and `git log <base>...HEAD --oneline`; reason about categories from file paths and commit messages together (reference sections 2–3).
2. Assign every file to a category with an awk script (reference section 4) and verify the TOTAL row against `--shortstat` — fix the awk if it doesn't match, never eyeball the totals.
3. Render the fixed-width table per the reference's section 5 format, plus the one-sentence interpretation from section 6.

Insert the result into the PR body as its own section, placed after Summary/Changes:

```markdown
## Change Breakdown

The line count is large but much of it is <one-sentence explanation of dominant non-production categories>:

\`\`\`
 <table>
\`\`\`
```

If the template already has a section clearly meant for this (e.g. "## Size" or "## Diff Stats"), fill that section instead of adding a duplicate. Then continue to Step 4 with the augmented body.

## Step 4 — Preview and Confirm

Show the user the proposed PR using `AskUserQuestion`:

```text
Here's the PR I'll create:

**Title:** feat: add retry logic for upstream API timeouts

**Body:**
---
<rendered body>
---

How would you like to proceed?
1. Create PR as-is
2. Edit the title
3. Edit the body
4. Create as draft instead
5. Cancel
```

Handle their choice:

- **Edit title / body**: ask for the replacement text, then re-show the preview.
- **Draft**: set the draft flag and proceed.
- **Cancel**: stop cleanly.

## Step 5 — Push and Create

**Push if needed:**

```bash
git push -u origin $(git branch --show-current)
```

Only push if the branch has no upstream yet (`git branch --show-current` + `git remote show origin` to check). If the push fails, report the error and stop.

**Create the PR:**

```bash
gh pr create \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body>
EOF
)" \
  [--draft] \
  [--base <base-branch>] \
  [--reviewer <handle> ...]
```

## Step 6 — Report

After successful creation, output the PR URL (from `gh pr create` stdout).

## Error Handling

| Situation | Action |
|---|---|
| On `main`/`master` branch | Stop — instruct user to switch to a feature branch |
| Push rejected (non-fast-forward) | Report error, do not force push, suggest user investigate |
| `gh pr create` fails (already exists) | Show existing PR URL from the error output |
| No Jira key found and user skips | Omit the Jira link; continue without it |
| Template not parseable | Fall back to minimal template; warn the user |
| Diff breakdown totals don't match `--shortstat` | Recompute the awk categorization; never hand-adjust numbers to fit |

## Reference files

- `references/diff-breakdown.md` — diff categorization workflow used by Step 3.5 to build a "Change Breakdown" section for big PRs

# Other common operations

- View comments on a Github PR: gh api repos/foo/bar/pulls/123/comments
