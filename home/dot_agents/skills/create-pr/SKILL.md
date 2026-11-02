---
name: create-pr
description: "create or update a GitHub PR. Repo template slots + `pr` skill body + diff breakdown on big PRs."
disable-model-invocation: true
---

Create or update the GitHub PR for the current branch. The body has three layers:

- **Template slots** from the repo's PR template: what reviewers or tooling depend on.
- **The `pr` body** (Summary, Evidence, Merge Danger): what the change is and proof that it works.
- **A diff breakdown** when the PR is big.

The goal is a body a reviewer can read in about one minute. Supporting detail goes into collapsed `<details>` blocks.

## Arguments

Parse `$ARGUMENTS`:

- `-d` / `--draft`: create as draft (create mode only).
- `--reviewer <handle>`: add a reviewer. Repeatable.
- `--base <branch>`: override the base branch.
- `--no-template`: skip the template. Use only the `pr` body.
- `--big-threshold <n>`: changed-line count that makes a PR big. Default `400`.
- A bare Jira key (`ENP-123`): override the detected key.
- A quoted string: the PR title.

## 1. Branch, base, and mode

1. If the branch is `main` or `master`, stop. Tell the user to switch to a feature branch.
2. Detect a stack: `gh stack view --json`. Exit 0 means the branch is in a **stack**. Exit 2 means no stack. Any other exit or a missing `gh stack` extension also means no stack. For all `gh stack` commands, obey the non-interactive rules in `~/.agents/skills/gh-stack/SKILL.md`.
3. Find the PR for the branch: `gh pr view --json number,url,baseRefName,body,title,isDraft`.
   - A PR exists → **update mode**. The base is the PR's `baseRefName`.
   - No PR → **create mode**. In a stack, the base is the branch directly below the current branch in `branches[]`, or `trunk` for the bottom branch. Ignore `--base` and tell the user. With no stack, the base is `--base`, or `main`.
4. If the base is not `main`/`master`, the PR is **stacked**. In a stack, take the parent PR number from that branch's `pr.number` in the `gh stack view --json` output. With no stack, use `gh pr list --head <base>`.
5. Get the Jira key: the argument, then the branch name (`PROJ-58/feat/x`, `feat/PROJ-58-x`), then the existing body (update mode). If none is found, ask the user once. For a stack, reuse the same answer for every PR in the stack.

Done when: mode, base, stack parent (if any), and Jira key (or "skip") are known.

## 2. Template slots

Find the template (first match, unless `--no-template`):

```bash
find . -maxdepth 3 \( -name "PULL_REQUEST_TEMPLATE.md" -o -path "./.github/PULL_REQUEST_TEMPLATE/*.md" \) -not -path "./.git/*"
```

If there is more than one template, ask the user which to use.

Sort each template section into one of two kinds:

- **Slot:** content that someone depends on. Examples: a Jira link, a deployment note, a checklist. Keep the heading. Fill the slot. Keep checklist item text exactly. Check the items that the diff, tests, or evidence show are done.
- **Prompt:** instructions to the author ("Add background information…", "Why are we making this change?"). Delete the instruction text. The `pr` body answers it.

Keep a section that does not fit either kind, and tell the user about it in the preview.

Fill these slots:

- **Jira link:** `[KEY]($JIRA_URL/browse/KEY)`, or the repo's own URL pattern if the template has one. With no key, keep `<!-- TODO: add Jira link -->`.
- **Background** (or the template's equivalent): one or two short paragraphs about why the change exists. If stacked, the first line is `Stacked on #N. Merge that first.`
- **Deployment:** special steps, or `None.`

In update mode, keep slot content that the author wrote by hand: a filled Jira link, a deployment note, checked boxes.

With no template, use `Background`, then the `pr` body.

## 3. The `pr` body

Read the `pr` skill (`~/.agents/skills/pr/SKILL.md`). Write its Summary, Evidence, and Merge Danger sections. Put them after Background and before Deployment. Use `-----` underlines when the template uses them, so the headings match.

Read the diff (`git diff <base>...HEAD`) and the commits (`git log <base>..HEAD`) first. In update mode, also read the current body: it often holds evidence and decisions that the diff does not show.

Rules on top of `pr`:

- **Evidence has a source.** Every claim points to a test, a corpus or fixture diff, a run table, or command output. A before/after table is the default form. If you find no evidence, write `<!-- TODO: evidence -->` and say so in the preview.
- **Visible vs collapsed.** Keep visible: the key Summary visual, the main Evidence table, and Merge Danger. Put method, inputs, history, rejected options, and secondary tables into `<details><summary>…</summary>` blocks.
- **One paragraph per line.** Do not hard-wrap prose. Code fences, lists, and tables keep their line breaks.

Done when: each change in the diff appears in Summary, and each Evidence claim has a source or a TODO.

## 4. Diff breakdown (big PRs only)

```bash
git diff <base>...HEAD --shortstat
```

The PR is big when insertions + deletions are more than the threshold, or when it changes more than 15 files. If it is not big, skip this step.

If it is big, obey `references/diff-breakdown.md`. The TOTAL row must match `--shortstat`. Put the result as a visible `Change Breakdown` section directly after Summary, outside any `<details>`.

## 5. Title

- Create mode: `<type>: <what this PR does>`, 72 characters or fewer. Take the type from the commits (feat > fix > refactor > chore). A quoted argument overrides it.
- Update mode: keep the current title unless the user asks for a new one, or the scope changed. If the scope changed, propose a new title in the preview.

## 6. Preview

Write the body to `/tmp/pr-<branch>.md`. Ask the user to confirm and show:

- the file path (the user reads the full body there)
- the title
- the section list, with one line for each section
- any TODOs, unsorted template sections, and whether a breakdown was added

Options: create/update as-is, edit, draft (create mode), cancel. After an edit, show the preview again.

## 7. Publish

With no stack:

- Create mode: if the branch has no upstream, run `git push -u origin <branch>`. Then run `gh pr create --title … --body-file /tmp/pr-<branch>.md [--draft] [--base …] [--reviewer …]`.
- Update mode: run `gh pr edit <number> --body-file /tmp/pr-<branch>.md [--title …]`.
- If the push is rejected, report it and stop. Do not force push.

In a stack (do not use `git push` or `gh pr create`):

- Create mode:
  1. Run `gh stack submit --auto`. It pushes every branch in the stack and opens a draft PR for each branch without a PR. Say this in the preview when other branches have no PR.
  2. Get the new PR number: `gh pr view --json number`.
  3. Run `gh pr edit <number> --title … --body-file /tmp/pr-<branch>.md [--add-reviewer …]`.
  4. Without `-d`/`--draft`, run `gh pr ready <number>`. Do not use `submit --open`, because it marks every PR in the stack ready.
- Update mode: if the local branch is ahead of its upstream, run `gh stack push`. Then run `gh pr edit <number> --body-file /tmp/pr-<branch>.md [--title …]`.
- If `gh stack` exits non-zero, report the exit code and stderr, and stop. Do not force push.

Report the PR URL and any TODOs left in the body.
