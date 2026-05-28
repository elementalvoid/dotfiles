# Jira API gotchas

Real Jira Cloud landmines that exist regardless of what client you use. The `jira` CLI handles most of these for you; this file is for cases where the gotcha is fundamental to Jira's data model and worth knowing.

For *how the CLI's flags work*, see `cli.md`. For *what node types ADF supports*, see `adf.md`.

---

## 1. Descriptions and comment bodies are ADF, not Markdown or wiki markup

If you send `**bold**` or `h2. Title` as a plain string into a description field, Jira stores it as literal characters. Rich-text fields require **ADF** (Atlassian Document Format) JSON.

The `jira` CLI handles this transparently: pass `--md FILE` and it converts Markdown (with container syntax — see SKILL.md) to ADF before posting. Only fall back to `--adf FILE` for ADF-only constructs (status badges, mentions, inlineCards).

Symptom if you bypass the CLI and send a raw string: the issue shows `**bold**` verbatim in the description.

---

## 2. Epic → Story is `parent` (a first-class field), not a link

Epic children use the `parent` field on creation, not an issue link. The CLI's `--parent KEY` flag on `create` does this. **Do not also create a link of type "Parent"** — you'll end up with a duplicate relationship that's awkward to clean up.

**Reading parent back:** Jira's default field set on `GET /issue/KEY` does not include `parent`. The CLI's `jira view` includes it in the default field list, but if you call the REST API directly, ask for it explicitly:

```bash
jira view KEY --fields 'key,summary,parent'
```

**Dual-field storage on older projects:** projects that predate the modern hierarchy store the epic link in both `parent` (modern) and `customfield_10006` (legacy "Epic Link"). Jira back-fills both automatically. For JQL, try `parent = ENP-1` first; if it returns zero, fall back to `"Epic Link" = ENP-1`.

---

## 3. JQL is project- and site-specific

Status names, link type names, custom field names, and issue type names are all configurable per project or per site. Before scripting bulk operations against an unfamiliar project, run:

```bash
jira issue-types <PROJECT>    # valid issue types
jira link types                # link types
jira transition <ANY_KEY>     # transitions available from a state
jira view <ANY_KEY> --fields status   # exact spelling of statuses in use
```

The CLI case-folds names and resolves canonical forms via REST, but it can't guess names that don't exist.

---

## 4. Jira Cloud rate-limits aggressively

The API will return 429 Too Many Requests on bursts of writes — especially `link create` and `comment add` in tight loops. The CLI retries 429s (and 5xx responses) up to 4 times with exponential backoff (0.5s, 1s, 2s, 4s) honouring the `Retry-After` header.

If you're seeing persistent 429s:

- Use `jira create-bulk` instead of looping `jira create` (one round-trip, no per-issue throttling).
- For link/transition bursts, add a small `sleep` between calls in your driver script.

---

## 5. Custom fields are stored under opaque `customfield_NNNNN` ids

When `jira view --fields '*all'` shows a field like `customfield_10042` with a value, that's a site-specific custom field (sprint, story points, epic link, team, etc.). To find the human name for one:

```bash
jira view KEY --fields '*all' --markdown    # readable rendering with known field names
# Or query the field metadata directly:
curl -u "$JIRA_API_USER:$JIRA_API_TOKEN" \
    "$JIRA_BASE_URL/rest/api/3/field" | jq '.[] | select(.id == "customfield_10042")'
```

Setting custom fields from `jira edit` is not currently supported via dedicated flags — fall back to the REST API (`PUT /issue/KEY` with `{"fields": {"customfield_10042": ...}}`) and consider adding a flag to the CLI if it comes up repeatedly.

---

## 6. `assignee` on create is unreliable; the CLI works around it

Some Jira projects require an explicit assignee permission distinct from "create issue" permission. Setting `assignee` in the same payload as the create call sometimes succeeds and sometimes silently no-ops.

The CLI handles this by always doing assignment as a **second step** after creation. You don't need to think about it — `jira create --assignee @me ...` does the right thing.

---

## 7. Keep Markdown drafts in version control, not Jira

The MD file is the source humans review and redline. The ADF JSON in Jira is generated output. If a description needs to change:

- ✅ Edit the MD file → `jira edit KEY --md plan.md`
- ❌ Hand-patch the ADF JSON or edit in the Jira UI

Hand-patched JSON and UI-edits drift from the plan doc, and nobody can later reconstruct what the "official" description is supposed to say. If a UI edit must happen (e.g. an exec edited it in-browser), `jira view KEY --markdown > plan.md` to round-trip back.
