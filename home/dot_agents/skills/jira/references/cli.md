# `jira` CLI reference

Complete reference for `scripts/jira`. SKILL.md has the workflow framing; this file is the verb-by-verb manual.

## Global flags & output mode

**Single-stream output.** Each invocation prints exactly one thing to stdout. stderr is reserved for errors only — never duplicated renderings, never status messages.

The mode is **TTY-aware** by default:

| stdout is... | Default |
|---|---|
| a terminal | Markdown to stdout |
| a pipe or file | JSON to stdout |

Force a mode (mutually exclusive):

```text
--json       Force JSON to stdout.
--markdown   Force Markdown to stdout.
--quiet      Suppress stdout entirely (exit code only).
```

All flags work in any position (`jira --markdown view K`, `jira view --markdown K`, and `jira view K --markdown` are equivalent).

### Terminal hyperlinks (OSC 8)

When human output goes to a TTY, issue keys and other links are emitted as OSC 8 terminal hyperlinks (`ESC ]8;;URL ESC \ TEXT ESC ]8;; ESC \`). Supported by Kitty, iTerm2 (≥3.1), WezTerm, Ghostty, modern xterm, VS Code's terminal, and others; terminals that don't understand OSC 8 simply print the visible text.

When output is piped or redirected (no TTY), `jira` emits Markdown `[text](url)` links instead, so the URLs remain visible in files, logs, and chat clients.

Set `NO_COLOR=1` to force the Markdown form even on a TTY.

## Authentication

The CLI reads, in order:

- `JIRA_API_USER` → falls back to `ATLASSIAN_API_USER`
- `JIRA_API_TOKEN`    → falls back to `ATLASSIAN_API_TOKEN`
- `JIRA_BASE_URL` → falls back to `ATLASSIAN_BASE_URL`

Generate a token at <https://id.atlassian.com/manage-profile/security/api-tokens>. The CLI retries 429s and 5xx responses automatically (up to 4 attempts with exponential backoff).

## `jira ping`

Verify connectivity and auth. Returns server info + the authenticated user.

```bash
jira ping
```

## `jira me`

Show the authenticated user (name, email, accountId).

```bash
jira me
```

## `jira view KEY [KEY...]`

Fetch one or more issues.

| Flag | Effect |
|---|---|
| `--comments` | Also fetch comments. |
| `--fields F1,F2,...` | Override the default field set. Pass `*all` for everything, `*navigable` for the useful subset. |

Default fields: `summary, issuetype, status, assignee, reporter, priority, labels, parent, description, issuelinks, created, updated`.

The human renderer converts the ADF description and comment bodies back to Markdown via `adf_to_markdown.py`, and emits browse URLs for the issue and any linked work items.

```bash
jira view ENP-134            # auto-markdown on a TTY
jira view ENP-134 ENP-135 --comments
jira view ENP-134 --fields '*all'
```

## `jira search --jql 'QUERY'`

Search via JQL.

| Flag | Effect |
|---|---|
| `--jql QUERY` | Required. Standard JQL — same as the Jira UI's advanced search. |
| `--fields F1,F2,...` | Fields to return for each issue. Default: `summary, status, issuetype, assignee, priority, labels`. |
| `--limit N` | Page size (default 50, max 100 on Jira's side). |
| `--all` | Paginate through every match. Ignores `--limit`. |

Returns `{jql, issues, count, isLast, nextPageToken}` for paged calls, or `{jql, total, issues}` with `--all`.

```bash
jira search --jql "project = ENP AND status = 'In Progress'"
jira search --jql "parent = ENP-44" --all
jira search --jql "assignee = currentUser() AND resolution is EMPTY" --fields key,summary
```

Common JQL patterns:

```text
project = ENP AND type = Bug AND status != Done
assignee = currentUser() AND status != Done
project = ENP AND created >= startOfWeek()
parent = ENP-44                                  # epic's children
"Epic Link" = ENP-44                             # legacy epic-link field if `parent` returns 0
project = ENP AND updated >= -7d ORDER BY updated DESC
project = ENP AND labels = 'tech-debt'
```

## `jira edit KEY [...]`

Update one or more fields on an issue. At least one change is required.

| Flag | Effect |
|---|---|
| `--summary TEXT` | New summary. |
| `--md FILE` / `--adf FILE` | New description (mutually exclusive). `-` for stdin. |
| `--add-labels A,B,C` | **Add** these labels to the existing set (deduped by Jira). |
| `--remove-labels A,B` | **Remove** these labels. Combinable with `--add-labels` in one call. |
| `--set-labels A,B,C` | **Replace** the entire label set. Mutually exclusive with `--add-labels` / `--remove-labels`. |
| `--type NAME` | New issue type. Case-insensitive; canonical name resolved via REST. |
| `--assignee SPEC` | See [User specs](#user-specs). |

Label ops use Jira's atomic per-field update API, so concurrent edits by other users aren't clobbered (only the specific labels you add/remove change).

```bash
jira edit ENP-134 --md plan.md
jira edit ENP-134 --summary "Updated title" --add-labels "tech-debt,api"   # adds both
jira edit ENP-134 --add-labels new1 --remove-labels stale,old             # one round-trip
jira edit ENP-134 --set-labels "only,these"                                # replaces wholesale
jira edit ENP-134 --type Bug                                           # case-insensitive
jira edit ENP-134 --assignee @me
```

## `jira create [...]`

Create a new issue. Two modes: from scratch (requires `--project`, `--type`, `--summary`) or `--from KEY` (clone-style, REST-backed).

### From scratch

| Flag | Effect |
|---|---|
| `--project KEY` | Project key, e.g. `ENP`. Required. |
| `--type NAME` | Issue type. Case-insensitive. Required. |
| `--summary TEXT` | Issue summary. Required. |
| `--parent KEY` | Parent (epic) key. First-class field — do NOT also create a "Parent" link. |
| `--md FILE` / `--adf FILE` | Description body. |
| `--labels A,B,C` | Labels. |
| `--assignee SPEC` | Applied as a second step after creation (see [User specs](#user-specs)). |

```bash
jira create --project ENP --type Story --parent ENP-44 \
    --summary "Short, specific title" --md story.md
```

### `--from KEY` (REST-backed clone replacement)

Reads the source issue's `summary`, `issuetype`, `labels`, `parent`, and `description` via REST and creates a fresh issue with those fields. **Never copies comments or links.**

| Flag | Effect |
|---|---|
| `--from KEY` | Source issue. |
| `--summary TEXT` | Override the copied summary. Default: `"Copy of <source summary>"`. |
| `--type NAME` | Override the copied type. |
| `--project KEY` | Override target project (cross-project copy). |
| `--parent KEY` | Override parent. By default, the source's parent is preserved. |
| `--no-parent` | Drop the parent entirely. |
| `--md FILE` / `--adf FILE` | Override description. |
| `--labels A,B,C` | Override labels. |
| `--assignee SPEC` | Assign after creation. |

```bash
jira create --from ENP-136 --summary "Bug variant for iOS" --type Bug
jira create --from ENP-136 --parent ENP-44 --md new-plan.md
```

This replaces `acli clone`, which silently dropped the parent and forced delete-and-recreate to fix.

## `jira create-bulk INPUT.json`

Create many issues in one round-trip.

Input is a JSON array. Each item is an object:

```json
[
  {
    "project": "ENP",
    "type": "Story",
    "summary": "First child",
    "parent": "ENP-44",
    "labels": ["api"],
    "assignee": "alice@example.com",
    "description_md": "# Heading\n\nBody text..."
  },
  {
    "project": "ENP",
    "type": "Story",
    "summary": "Second child",
    "parent": "ENP-44",
    "description_adf": { "type": "doc", "version": 1, "content": [] }
  }
]
```

Required per item: `project`, `type`, `summary`. Optional: `parent`, `labels`, `assignee`, `description_md`, `description_adf` (mutually exclusive).

Assignees are applied as a second step per issue (Jira's create-with-assignee is unreliable across project configurations).

Exits non-zero if any item in the bulk response includes an error.

## `jira link <BLOCKER> --blocks <BLOCKED>`

Add a link. Semantics: **`<blocker>` blocks `<blocked>`** — i.e. the blocker must complete first.

| Flag | Effect |
|---|---|
| `--blocks KEY` | The downstream (inward) issue. Required. |
| `--type NAME` | Link type. Default `Blocks`. Case-insensitive. Also accepts outward/inward descriptions like `'is blocked by'` or `'relates to'`. |

```bash
jira link ENP-44 --blocks ENP-45                   # ENP-44 blocks ENP-45
jira link ENP-44 --blocks ENP-45 --type Relates    # generic relation
jira link ENP-44 --blocks ENP-45 --type 'is blocked by'  # canonicalized to "Blocks"
```

### `jira link list KEY`

List all links on an issue with their LinkIds (needed for `link delete`).

```bash
jira link list ENP-44
```

### `jira link delete LINK_ID`

Delete by LinkId (get the id from `link list`).

```bash
jira link delete 414093
```

### `jira link types`

Show all link types configured on the site.

```bash
jira link types
```

## `jira transition KEY [STATUS]`

| Flag | Effect |
|---|---|
| (no STATUS) | List available transitions from the issue's current state. |
| `STATUS` | Transition to that target status. Case-insensitive; matches transition name or target status name. |

```bash
jira transition ENP-134                  # list options
jira transition ENP-134 "In Progress"    # do it
jira transition ENP-134 done             # case-insensitive
```

## `jira comment add KEY`

Add a comment.

| Flag | Effect |
|---|---|
| `--md FILE` / `--adf FILE` | Comment body. Required (use `-` for stdin). |
| `--edit-last` | Edit the current user's most recent comment on this issue instead of posting a new one. |

```bash
jira comment add ENP-134 --md update.md
echo "Quick status update" | jira comment add ENP-134 --md -
jira comment add ENP-134 --md update.md --edit-last
```

## `jira comment edit KEY --id COMMENT_ID`

Edit a specific comment.

```bash
jira comment edit ENP-134 --id 10001 --md fix.md
```

## `jira assign KEY USER_SPEC`

```bash
jira assign ENP-134 @me
jira assign ENP-134 alice@example.com
jira assign ENP-134 "Alice Smith"
jira assign ENP-134 none           # clear assignee
jira assign ENP-134 default        # project's default assignee
```

## `jira users QUERY`

Search for users by display name or email. Returns one row per match. The accountId in the JSON output is what you need for:

- The `@mention` ADF node (build via `adf_builder.py`)
- Disambiguating `--assignee` when a name matches multiple people
- Any direct REST call that wants an accountId

| Flag | Effect |
|---|---|
| `--include-apps` | Include app/bot accounts. Default: humans only (`accountType == "atlassian"`). |
| `--active-only` | Filter to active users only. |
| `--limit N` | Cap the result count (0 = no cap). |

```bash
jira users alice@example.com
jira users "Alice Smith"
jira users matt                   # quick lookup by partial name (markdown on TTY)
jira users matt --quiet | jq -r '.[0].accountId'   # script-friendly
```

Human output format: `<accountId>  <displayName> <<email>> [inactive] [accountType]`.

## `jira issue-types PROJECT`

List the issue types valid in a project (including descriptions). Useful before `create` if you're not sure what types are available.

```bash
jira issue-types ENP
```

## User specs

Accepted by `--assignee` (on `edit`, `create`, `create-bulk`) and by `assign`:

| Spec | Meaning |
|---|---|
| `@me` | The authenticated user (calls `/myself`). |
| `default` | The project's default assignee (Jira's `-1` sentinel). |
| `none` / `unassign` / `unassigned` | Clear the assignee. |
| email address | Looked up via `/user/search`. Most reliable. |
| display name or partial name | Looked up via `/user/search`; errors if ambiguous. |

For ambiguous lookups (e.g. "alice" matches two users), the CLI errors and asks for an email.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Operation failed (HTTP error, validation failure, missing file, ambiguous user, etc.) |
| 130 | Interrupted (Ctrl-C) |

## Out of scope

These are deliberately not implemented. Use the Jira web UI:

- `clone` — use `create --from KEY` instead
- `archive` / `unarchive` / `delete`
- Bulk-edit-by-JQL, bulk-transition-by-JQL, bulk-assign-by-JQL
- Cross-project bulk move
