---
name: jira
description: Drive Jira Cloud from the terminal using the purpose-built `jira` CLI in this skill — read issues, search via JQL, create/edit issues (including children under an epic with `--parent`), link dependencies with sane semantics (`<blocker> --blocks <blocked>`), transition status, add/edit comments, upload file attachments, and assign users. Rich text is authored in Markdown (with `:::panel`, `:::expand`, `:::quote` containers for ADF-only constructs) and converted to ADF automatically; ADF can also be supplied directly when needed. Use this skill whenever the user asks to view/edit/create Jira issues, plan out an epic's children, update an issue description from a plan or mind-map, wire up "blocks"/"is blocked by" relationships, push a planning doc into Jira, or transition a workflow. Also use it any time the user mentions Atlassian, ADF, JQL, or wants to push a planning doc into Jira — even if they don't explicitly say "Jira."
---

# Jira CLI

`scripts/jira` is a self-contained CLI that talks directly to Jira Cloud REST. Use it — don't write shell or Python wrappers. For full verb-by-verb usage see `references/cli.md`; for API landmines see `references/gotchas.md`.

## TL;DR

```bash
# Setup (once): get a token at https://id.atlassian.com/manage-profile/security/api-tokens
export JIRA_API_USER="you@example.com"
export JIRA_API_TOKEN="..."
export JIRA_BASE_URL="https://your-site.atlassian.net"
<skill>/scripts/jira ping        # verify (needs `uv` on PATH)

# Read
jira view ENP-134                                              # TTY: markdown; pipe: JSON
jira search --jql "parent = ENP-44" --all

# Write
jira edit ENP-134 --md plan.md
jira create --project ENP --type Story --parent ENP-44 --summary "..." --md story.md
jira link ENP-44 --blocks ENP-45
jira transition ENP-134 "In Progress"
jira comment add ENP-134 --md update.md
jira attach ENP-134 screenshot.png                            # upload an attachment
jira users "Alice"                                             # find accountIds
```

`ATLASSIAN_API_USER` / `ATLASSIAN_API_TOKEN` / `ATLASSIAN_BASE_URL` are accepted as fallbacks.

## Output

Single-stream; stderr is errors only. TTY → Markdown, pipe → JSON. Force with `--json` / `--markdown` (mutually exclusive); `--quiet` suppresses stdout entirely (for write commands you only care about the exit code of). Issue keys render as OSC 8 hyperlinks on a TTY; set `NO_COLOR=1` to force `[text](url)` form.

### Displaying results to the user (agent sessions)

The bash tool is **not** a TTY, so auto-detect returns JSON. When the user asks to *see* a Jira issue, search result, or comment:

1. Run with explicit `--markdown` (e.g. `jira --markdown view ENP-44`).
2. **Reproduce the CLI's markdown output verbatim in your reply** — not inside a code fence — so the chat TUI renders tables, links, headings, and emphasis. The raw bash-output panel won't render markdown; only your assistant reply will.
3. Optionally add a one-sentence summary after the rendered block.

Use `--json` (or the default in a pipe) only when you're going to parse / filter / transform the result, not when you're showing it to the user.

## Workflow

1. **Read** with `jira view` or `jira search`.
2. **Draft** changes in a Markdown file (`<key>-plan.md`) — keep this file as source of truth.
3. **Push** in one step: `jira edit KEY --md plan.md` (CLI converts MD→ADF internally).
4. **Verify** with another `jira view`, especially after creating links. Dependency direction should match reading order: "Spike → Emitter" means Spike `--blocks` Emitter.

Don't hand-edit ADF JSON or edit descriptions in the web UI — both drift from the plan file.

## Rich text: Markdown with containers

`--md` accepts GitHub-flavored Markdown plus three fenced containers for ADF-only blocks:

````markdown
:::panel warning            <!-- info | warning | note | success | error -->
**Heads up:** ...           <!-- Coloured admonition box. -->
:::

:::expand "Title"           <!-- Collapsible section; quotes optional. -->
Body. Containers nest.
:::

:::quote                    <!-- Multi-paragraph blockquote, no `>` per line. -->
...
:::
````

Containers nest; use `:::::` (more colons) to wrap a container holding a literal `:::` line. For **inline** ADF constructs MD can't express (status badges in running text, `@mention` with an accountId, `inlineCard`), hand-build ADF with `scripts/adf_builder.py` (`doc`, `para`, `panel`, `expand`, `b`, `link`, ...) and pass `--adf FILE` instead of `--md`. See `references/adf.md` for raw node shapes.

## Common commands

```bash
jira view K [K2...]                                            # batch read; --comments, --fields
jira search --jql "..." [--all] [--limit N]                    # JQL; --all paginates everything
jira edit K --md plan.md                                        # also --summary, --add-labels, --remove-labels, --set-labels, --type, --assignee, --sprint
jira edit K --sprint current                                    # current/active sprint on the issue's board (or <id>, none/backlog)
jira create --project P --type Story --parent E --summary "..." --md s.md
jira create --from K                                            # REST clone replacement: preserves parent, drops comments
jira create-bulk issues.json                                    # JSON array; one round-trip; prefer for 5+ issues
jira link <blocker> --blocks <blocked> [--type ...]             # semantic naming; verify with `link list <blocker>`
jira link list K   /   link delete <id>   /   link types
jira transition K [STATUS]                                      # no STATUS = list available transitions
jira comment add K --md u.md [--edit-last]                      # add new, or edit your most recent
jira attach K file.png [more.pdf ...]                           # upload file attachment(s)
jira assign K (@me | email | "Display Name" | none | default)
jira users QUERY                                                # find accountId by name/email
jira issue-types P   /   me   /   ping
```

Out of scope (use the Jira web UI): `clone` (use `create --from`), `archive`/`unarchive`/`delete`, bulk-edit/transition/assign-by-JQL, cross-project clone.

## Reference files

- `references/cli.md` — verb-by-verb reference (read for non-trivial usage)
- `references/gotchas.md` — Jira API landmines the CLI can't shield you from
- `references/adf.md` — ADF node/mark reference for raw-ADF use
- `scripts/jira` — the CLI (PEP-723; needs `uv` on PATH)
- `scripts/adf_{from,to,builder}.py` — MD↔ADF helpers; used by the CLI, also callable directly
