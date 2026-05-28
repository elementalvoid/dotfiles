# ADF (Atlassian Document Format) reference

This is a pragmatic reference for writing ADF by hand or extending the helpers in `scripts/adf_builder.py`. For the official, exhaustive spec and per-node attribute tables, see:

- **Overview:** https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
- **JSON schema:** http://go.atlassian.com/adf-json-schema
- **Per-node pages:** `/cloud/jira/platform/apis/document/nodes/<name>` (e.g., `.../nodes/paragraph`)

Before reaching for this file, check whether `scripts/adf_from_markdown.py` (Markdown → ADF) or `scripts/adf_to_markdown.py` (ADF → Markdown) can do the job — those converters handle almost every description we actually write, in both directions. This reference is for when you need to reach past the converters and emit (or interpret) a node type they don't cover: panels, expands, mentions, inline cards, status pills, colored text, media, etc.

## Mental model

An ADF document is a JSON tree of **nodes**. Every node has:

- `type` (required) — e.g. `paragraph`, `heading`, `text`.
- `content` — required for block/container nodes, forbidden on pure inline nodes like `text`. It's an ordered array of child nodes.
- `attrs` — node-specific attributes (heading `level`, codeBlock `language`, link `href`, etc.).
- `marks` — text decorations; only on inline text nodes.
- `version` — only on the root `doc`, and only `1` is valid today.

There are three flavors of node:

1. **Root** — exactly one: `doc`.
2. **Block** — structural; paragraphs, headings, lists, tables, code blocks, quotes, rules, panels, etc. Block nodes can nest block nodes inside their `content`.
3. **Inline** — live inside a block's content array. Text, hardBreak, emoji, mention, inlineCard, date, status, mediaInline. Inline nodes never have a `content` field.

Marks are not nodes; they're decorators attached to a `text` node via its `marks` array. A text node can carry multiple marks (e.g., bold + italic + link).

Documents are **ordered** — concatenating nodes in depth-first order reproduces the reading sequence.

## The document envelope

```json
{
  "version": 1,
  "type": "doc",
  "content": [ /* block nodes */ ]
}
```

The minimum valid document is `{"version":1,"type":"doc","content":[]}`.

## Block nodes

### Top-level blocks (may appear directly under `doc`)

- `paragraph`
- `heading` (level 1–6)
- `bulletList`
- `orderedList`
- `codeBlock`
- `blockquote`
- `rule` (horizontal rule)
- `panel` (info/warning/note boxes)
- `table`
- `mediaSingle`, `mediaGroup` (images/files; require pre-uploaded attachment IDs)
- `expand` (collapsible section)
- `taskList` (checklist)
- `bodiedSyncBlock`, `syncBlock`, `multiBodiedExtension` — specialty, rare in Jira descriptions

### Child-only blocks (must appear inside a specific parent)

- `listItem` — only inside `bulletList` / `orderedList`
- `taskItem`, `blockTaskItem` — only inside `taskList`
- `tableRow` — only inside `table`
- `tableCell`, `tableHeader` — only inside `tableRow`
- `media` — inside `mediaSingle` / `mediaGroup`
- `nestedExpand` — inside other collapsibles
- `extensionFrame` — specialty

### Paragraph

```json
{"type": "paragraph", "content": [ /* inline nodes */ ]}
```

An empty paragraph `{"type":"paragraph"}` (no `content`) renders as a blank line and is valid.

### Heading

```json
{
  "type": "heading",
  "attrs": {"level": 2},
  "content": [{"type": "text", "text": "Scope"}]
}
```

`level` is 1–6. Jira displays h1 very large; h2/h3 are the ones you usually want in descriptions.

### Bullet / ordered list

```json
{
  "type": "bulletList",
  "content": [
    {"type": "listItem", "content": [
      {"type": "paragraph", "content": [{"type": "text", "text": "item"}]}
    ]}
  ]
}
```

Constraints that catch people:

- `bulletList` / `orderedList` `content` arrays may contain **only** `listItem` nodes.
- `listItem.content` must begin with a **block** node (usually `paragraph`). You cannot put raw text or inline nodes directly inside a listItem.
- To nest: place another `bulletList` / `orderedList` **after** the paragraph inside the listItem.

`orderedList` supports `attrs.order` to start numbering at a value other than 1:

```json
{"type": "orderedList", "attrs": {"order": 5}, "content": [ /* listItems */ ]}
```

### Task list

Checkboxes. `localId` must be unique within the document.

```json
{
  "type": "taskList",
  "attrs": {"localId": "tasks-1"},
  "content": [
    {"type": "taskItem",
     "attrs": {"localId": "task-1", "state": "TODO"},
     "content": [{"type": "text", "text": "Write the thing"}]},
    {"type": "taskItem",
     "attrs": {"localId": "task-2", "state": "DONE"},
     "content": [{"type": "text", "text": "Ship it"}]}
  ]
}
```

`state` is `TODO` or `DONE`.

### Code block

```json
{
  "type": "codeBlock",
  "attrs": {"language": "python"},
  "content": [{"type": "text", "text": "print('hi')"}]
}
```

`attrs.language` is optional; omit the whole `attrs` field for unlabeled code. The `content` array must contain only `text` nodes (no marks, no other inline nodes).

### Blockquote

```json
{"type": "blockquote", "content": [
  {"type": "paragraph", "content": [{"type": "text", "text": "Quoted."}]}
]}
```

Can contain any block nodes — paragraphs, lists, even code blocks.

### Panel (info/warning/note boxes)

```json
{
  "type": "panel",
  "attrs": {"panelType": "info"},
  "content": [
    {"type": "paragraph", "content": [{"type": "text", "text": "Heads up."}]}
  ]
}
```

`panelType` values: `info`, `note`, `warning`, `success`, `error`. Panels are a nice way to call out audit-relevant notes in SOX/compliance tickets.

### Horizontal rule

```json
{"type": "rule"}
```

### Expand (collapsible)

```json
{
  "type": "expand",
  "attrs": {"title": "Implementation details"},
  "content": [ /* block nodes */ ]
}
```

Useful for putting long appendices inside a description without making the main body scroll forever.

### Table

```json
{
  "type": "table",
  "attrs": {"isNumberColumnEnabled": false, "layout": "default"},
  "content": [
    {"type": "tableRow", "content": [
      {"type": "tableHeader", "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": "Key"}]}
      ]},
      {"type": "tableHeader", "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": "Value"}]}
      ]}
    ]},
    {"type": "tableRow", "content": [
      {"type": "tableCell", "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": "foo"}]}
      ]},
      {"type": "tableCell", "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": "bar"}]}
      ]}
    ]}
  ]
}
```

Every cell's `content` must start with a block node. Wrap even single-word cells in a paragraph. `isNumberColumnEnabled` controls the automatic row-number column on the left; most descriptions want `false`. `layout` is `default`, `full-width`, or `wide`.

## Inline nodes

### Text

```json
{"type": "text", "text": "hello"}
```

Plain text. Must be non-empty. `content` is forbidden.

### Text with marks

```json
{
  "type": "text",
  "text": "important",
  "marks": [{"type": "strong"}, {"type": "em"}]
}
```

### Hard break

```json
{"type": "hardBreak"}
```

A line break *inside* a paragraph. Rarely needed — blank lines between paragraphs are usually what you want.

### Link

Links aren't their own node type — they're a **mark** on a text node:

```json
{
  "type": "text",
  "text": "the docs",
  "marks": [{"type": "link", "attrs": {"href": "https://example.com"}}]
}
```

### Inline code

Also a mark, not a node. This matters because inline code can still pick up other marks (though the resulting appearance is limited):

```json
{"type": "text", "text": "print()", "marks": [{"type": "code"}]}
```

### Rarely-used inline nodes

- **`mention`** — `@someone`. Requires the user's `accountId` from the Atlassian API, not their email: `{"type":"mention","attrs":{"id":"557058:abc...","text":"@Jane"}}`.
- **`emoji`** — `{"type":"emoji","attrs":{"shortName":":smile:","id":"1f604","text":"😄"}}`.
- **`date`** — ISO date pill: `{"type":"date","attrs":{"timestamp":"1735689600000"}}` (ms since epoch).
- **`inlineCard`** — rich link preview for a URL that Jira knows how to unfurl (Jira issues, Confluence pages, some external services): `{"type":"inlineCard","attrs":{"url":"https://..."}}`.
- **`status`** — colored pill badge: `{"type":"status","attrs":{"text":"IN PROGRESS","color":"yellow"}}`.
- **`mediaInline`** — image inline with text; requires an uploaded attachment's media ID.

If you need these, extend `adf_builder.py` with a helper rather than sprinkling raw JSON through your code.

## Marks

Marks listed in the spec; the ones in **bold** are the ones you'll actually use:

- **`strong`** — bold
- **`em`** — italic
- **`code`** — inline monospace
- **`link`** — requires `attrs.href`
- **`strike`** — strikethrough
- `underline`
- `subsup` — subscript/superscript: `attrs.type` is `sub` or `sup`
- `textColor` — `attrs.color` is a hex like `#ff5630`
- `border` — adds a border around the text (Confluence-ish)

Marks stack: a text node can carry many marks in one `marks` array. Order in the array is not meaningful for rendering.

## Media (images, attachments)

This is the most painful part of ADF. A `mediaSingle` or `mediaGroup` holds `media` child nodes that reference attachments **by ID**, not by URL:

```json
{
  "type": "mediaSingle",
  "attrs": {"layout": "center"},
  "content": [{
    "type": "media",
    "attrs": {
      "id": "abc-123-attachment-id",
      "type": "file",
      "collection": "",
      "width": 800,
      "height": 600
    }
  }]
}
```

Getting an ID requires uploading the file to the Jira attachment API first (not something `acli` exposes cleanly yet). For descriptions you almost always either (a) attach the file via the UI and let the user paste it in, or (b) use a public URL and rely on an `inlineCard` to unfurl it.

## Validation tips

- **Always include `version: 1`** at the top. Jira's API rejects documents without it.
- **Block containers need `content` arrays**, even empty ones, or Jira silently rejects the payload and falls back to a blank description.
- **Inline nodes must not have `content`.** A `text` node with `content` is invalid.
- **`listItem.content[0]` must be a block node**, typically `paragraph`. A common mistake is putting a text node directly inside a listItem — it looks like it should work but won't.
- **Unique `localId`s** on `taskList` / `taskItem` and on any node that takes one. Duplicates can cause weird rendering or silent drops.
- **Round-trip small first.** If an edit "succeeds" but the description disappears, shrink to a known-good minimal doc and add back one block at a time until it breaks.
