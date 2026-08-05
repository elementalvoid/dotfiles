---
name: jira
description: Drive Jira Cloud from the terminal using the purpose-built `jira` CLI in this skill — read issues, search via JQL, create/edit issues (including children under an epic with `--parent`), link dependencies with sane semantics (`<blocker> --blocks <blocked>`), transition status, add/edit comments, upload file attachments, and assign users. Rich text is authored in Markdown (with `:::panel`, `:::expand`, `:::quote` containers for ADF-only constructs) and converted to ADF automatically; ADF can also be supplied directly when needed. Use this skill whenever the user asks to view/edit/create Jira issues, plan out an epic's children, update an issue description from a plan or mind-map, wire up "blocks"/"is blocked by" relationships, push a planning doc into Jira, or transition a workflow, or says "begin work on <ticket>" / "let's start <ticket>" / "pick up <ticket>". Also use it any time the user mentions Atlassian, ADF, JQL, or wants to push a planning doc into Jira — even if they don't explicitly say "Jira."
---

# Jira CLI

`scripts/jira` is a self-contained CLI that talks directly to Jira Cloud REST. Use it — don't write shell or Python wrappers. Run `jira <cmd> --help` for flag reference. For API landmines see `references/gotchas.md`.

**Link direction reads left to right:** `jira link add A --blocks B` means *A blocks B*. Also `--blocked-by` for the other direction. See [Links](#links-direction-reads-left-to-right) — and never verify direction by eye, use `linkedIssues()` JQL.

**Path note:** `<skill>` below means *the directory containing this SKILL.md file* — i.e. `dirname` of whatever path you read to load these instructions. Don't assume a fixed location (e.g. `~/.pi/agent/skills/jira`); resolve it from how you actually got here, since skills can be loaded from more than one root.

## STOP: "begin work on KEY" means transition it first

If the user says begin / start / pick up / work on / take a ticket, run these **before** writing any code, reading any repo, or planning anything. The coding task does not replace this — do both, this part first:

```bash
jira view KEY                        # 1. read it; show the markdown to the user
jira transition KEY                  # 2. list available transitions (names vary per project)
jira transition KEY "In Progress"     # 3. pick the listed name meaning in-progress
jira assign KEY @me                   # 4. if unassigned
```

Steps 2–4 are not optional and not "nice to have at the end." Skip step 3 only if `view` already shows an in-progress status; ask first before reassigning away from another person. Report what you transitioned in one line, then get on with the work.

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
jira link add ENP-44 --blocks ENP-45          # ENP-44 blocks ENP-45
jira link add ENP-45 --blocked-by ENP-44      # identical link, stated the other way
jira transition ENP-134 "In Progress"
jira comment add ENP-134 --md update.md
jira attach ENP-134 screenshot.png                            # upload an attachment
jira users "Alice"                                             # find accountIds
```

`ATLASSIAN_API_USER` / `ATLASSIAN_API_TOKEN` / `ATLASSIAN_BASE_URL` are accepted as fallbacks.

## Output

Single-stream; stderr is errors only. **Markdown by default**; `--json` for raw JSON when you're going to parse it; `--quiet` suppresses stdout entirely. Issue keys render as OSC 8 hyperlinks on a TTY; set `NO_COLOR=1` to force `[text](url)` form.

### Keeping the session clean (agent sessions)

- Don't pass `--json` unless you're piping to `jq` or extracting a field. The markdown rendering is a fraction of the size and has everything you need.
- Narrow reads: `--fields summary,status` on `view`/`search`, `--limit N` instead of `--all`, and skip `--comments` unless comments are the point.
- Write commands (`edit`, `transition`, `assign`, `link`, `comment add`, `attach`): add `--quiet` and trust the exit code.
- When the user asks to *see* something, reproduce the markdown output verbatim in your reply (not in a code fence) — the bash-output panel doesn't render markdown, only your reply does.

## Workflow

1. **Read** with `jira view` or `jira search`.
2. **Draft** changes in a Markdown file (`<key>-plan.md`) — keep this file as source of truth.
3. **Push** in one step: `jira edit KEY --md plan.md` (CLI converts MD→ADF internally).
4. **Verify** with another `jira view`.

## Links: direction reads left to right

```bash
jira link add A --blocks B        # A blocks B
jira link add A --blocked-by B    # B blocks A  (same link, stated from A)
jira link add A --to B --type Duplicate   # A duplicates B (non-Blocks types)
```

The positional is always the **subject of the sentence**. So a dependency chain written in reading order — "spike, then implementation" — is `link add SPIKE --blocks IMPL`.

**Verifying direction: use JQL, not the rendered output.** `link list` labels are correct, but they're easy to misread on a `Blocks` link because Jira's REST field names (`inwardIssue`/`outwardIssue`) are inverted from intuition. The only unambiguous check is:

```bash
jira search --jql 'issue in linkedIssues("ENP-408","blocks")'         # what ENP-408 blocks
jira search --jql 'issue in linkedIssues("ENP-408","is blocked by")'  # what blocks ENP-408
```

When wiring up more than a couple of links, create them, then run one `linkedIssues()` query before reporting done. A whole dependency graph created backwards looks completely plausible in `link list` output.

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
jira link add A --blocks B | --blocked-by B | --to B --type T   # A is always the sentence subject
jira edit K --md plan.md                                        # also --summary, --add-labels, --remove-labels, --set-labels, --add-components, --remove-components, --set-components, --type, --assignee, --sprint
jira edit K --sprint current                                    # current/active sprint on the issue's board (or <id>, none/backlog)
jira create --project P --type Story --parent E --summary "..." --md s.md
jira create --from K                                            # REST clone replacement: preserves parent, drops comments
jira create-bulk issues.json                                    # JSON array; one round-trip; prefer for 5+ issues
jira link add A --blocks B                                      # "A blocks B"; also --blocked-by, --to
jira link list K   /   link delete <id>   /   link types
jira transition K [STATUS]                                      # no STATUS = list available transitions
jira comment add K --md u.md [--edit-last]                      # add new, or edit your most recent
jira attach K file.png [more.pdf ...]                           # upload file attachment(s)
jira assign K (@me | email | "Display Name" | none | default)
jira users QUERY                                                # find accountId by name/email
jira issue-types P   /   me   /   ping
```

Out of scope (use the Jira web UI): `clone` (use `create --from`), `archive`/`unarchive`/`delete`, bulk-edit/transition/assign-by-JQL, cross-project clone.

## JQL patterns

```text
project = ENP AND type = Bug AND status != Done
assignee = currentUser() AND status != Done
parent = ENP-44                                  # epic's children
"Epic Link" = ENP-44                             # legacy fallback if parent returns 0
project = ENP AND labels = 'tech-debt'
project = ENP AND updated >= -7d ORDER BY updated DESC
```

## `create-bulk` JSON schema

Input is a JSON array; each item:

```json
{
  "project": "ENP",
  "type": "Story",
  "summary": "...",
  "parent": "ENP-44",
  "labels": ["api"],
  "components": ["kestrel"],
  "assignee": "alice@example.com",
  "description_md": "# Heading\n\nBody..."
}
```

`project`, `type`, `summary` required. `description_md` and `description_adf` are mutually exclusive.

## Reference files

- `references/gotchas.md` — Jira API landmines the CLI can't shield you from
- `references/adf.md` — ADF node/mark reference for raw-ADF use
- `scripts/jira` — the CLI (PEP-723; needs `uv` on PATH)
- `scripts/adf_{from,to,builder}.py` — MD↔ADF helpers; used by the CLI, also callable directly
