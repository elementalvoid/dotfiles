"""Markdown -> ADF (Atlassian Document Format) converter.

Converts a subset of GitHub-Flavored Markdown into the ADF JSON that
Jira Cloud's REST API (and `acli jira workitem edit --description-file`)
expects.

Zero external dependencies -- pure stdlib. Designed for the kinds of
descriptions humans actually write in planning docs: headings, bullets,
bold/italic/code, links, tables, fenced code, blockquotes, task lists.

Supported:
    - ATX headings (`#`..`######`)
    - Paragraphs (blank-line separated)
    - Bullet lists (-, *, +)        with nesting via indent >= 2 spaces
    - Ordered lists (1., 2., ...)   with nesting
    - Task lists (- [ ] / - [x])    -> ADF taskList/taskItem
    - Blockquotes (>)               can contain lists, paragraphs, etc.
    - Fenced code blocks (``` with optional language)
    - Horizontal rules (--- / *** / ___, three or more)
    - GFM pipe tables (| col | col |\n|---|---|\n| a | b |)
    - Inline: **bold**, *italic*, `code`, ~~strike~~, [text](url), <url>
    - Hard breaks (two trailing spaces at end of line)
    - Fenced containers (pandoc-style) for ADF-only block types:
          :::panel info|warning|note|success|error
          ...content...
          :::

          :::expand "Title"
          ...content...
          :::

          :::quote
          ...content...
          :::
      Containers nest. Inner content is parsed as Markdown
      (including more containers).

Deliberately NOT supported (rare in Jira descriptions, or requires
Jira-specific ID lookups):
    - Images ![alt](url)   -- Jira requires a media node with an
      attachment ID, not a URL; generating one needs an API call.
    - @mentions / emoji    -- require accountId / emojiId lookups.
    - HTML passthrough     -- ADF has no generic html node.
    - Reference-style links ([text][ref]).
    - Setext-style headings (=== / --- underlines).
    - Nested blockquotes beyond one level are flattened.

CLI:
    python adf_from_markdown.py input.md > output.json
    python adf_from_markdown.py input.md --out output.json

Library:
    from adf_from_markdown import markdown_to_adf
    adf = markdown_to_adf(md_string)

Then:
    acli jira workitem edit --key KEY-1 --description-file output.json --yes
"""

from __future__ import annotations

import argparse
import json
import re
import sys


# ---------------------------------------------------------------------------
# Inline parsing
# ---------------------------------------------------------------------------

# Order matters: code spans are tokenized before anything else so that
# `**` inside backticks doesn't get interpreted as emphasis.
_AUTOLINK_RE = re.compile(r"<((?:https?|ftp|mailto):[^\s<>]+)>")
_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"([^\"]*)\")?\)")
_CODE_RE = re.compile(r"(`+)([^`]|(?!\1)`)+?\1")  # fallback; see _split_codespans
_STRONG_RE = re.compile(r"(\*\*|__)(?=\S)(.+?[*_]*)(?<=\S)\1")
_EM_RE = re.compile(r"(?<![*_\w])(\*|_)(?=\S)(.+?)(?<=\S)\1(?![*_\w])")
_STRIKE_RE = re.compile(r"~~(?=\S)(.+?)(?<=\S)~~")
_HARDBREAK_RE = re.compile(r"  +\n")


def _text_node(s: str, marks: list[dict] | None = None) -> dict:
    if not s:
        return None  # caller filters None
    node = {"type": "text", "text": s}
    if marks:
        node["marks"] = marks
    return node


def _with_mark(nodes: list[dict], mark: dict) -> list[dict]:
    """Add a mark to every text node in a list of inline nodes."""
    out = []
    for n in nodes:
        if n.get("type") == "text":
            existing = list(n.get("marks", []))
            # Don't duplicate the same mark type.
            if not any(m.get("type") == mark.get("type") for m in existing):
                existing.append(mark)
            copy = dict(n)
            if existing:
                copy["marks"] = existing
            out.append(copy)
        else:
            out.append(n)
    return out


def _split_codespans(text: str) -> list[tuple[str, str]]:
    """Split text into (kind, content) pairs where kind is 'text' or 'code'.

    Handles backtick runs correctly: a run of N backticks opens, and the
    next run of exactly N backticks closes. This lets you embed backticks
    inside code: `` `foo` `` -> code span containing "`foo`".
    """
    out: list[tuple[str, str]] = []
    i = 0
    n = len(text)
    while i < n:
        if text[i] == "`":
            # Find run of backticks.
            j = i
            while j < n and text[j] == "`":
                j += 1
            fence = text[i:j]
            # Find matching fence.
            end = text.find(fence, j)
            while end != -1 and end + len(fence) < n and text[end + len(fence)] == "`":
                # Not a matching fence (longer run); skip past it.
                end = text.find(fence, end + len(fence) + 1)
            if end == -1:
                # No closing fence -- treat as literal.
                out.append(("text", text[i:j]))
                i = j
            else:
                inner = text[j:end]
                # CommonMark: strip exactly one leading/trailing space if
                # both ends are non-space inside.
                if (
                    inner.startswith(" ")
                    and inner.endswith(" ")
                    and inner.strip() != ""
                ):
                    inner = inner[1:-1]
                out.append(("code", inner))
                i = end + len(fence)
        else:
            # Consume until next backtick.
            j = text.find("`", i)
            if j == -1:
                out.append(("text", text[i:]))
                i = n
            else:
                out.append(("text", text[i:j]))
                i = j
    return out


def _parse_text_run(text: str) -> list[dict]:
    """Parse a piece of text (no code spans) into inline nodes.

    Handles links/autolinks, then strong, then em, then strike, then
    hard breaks. We do this by repeatedly finding the earliest match and
    recursing on the surrounding pieces.
    """
    if not text:
        return []

    # Hard break: two+ spaces before newline.
    m = _HARDBREAK_RE.search(text)
    if m:
        before = text[: m.start()]
        after = text[m.end() :]
        return [
            *_parse_text_run(before),
            {"type": "hardBreak"},
            *_parse_text_run(after),
        ]

    # Newlines within a paragraph become spaces in ADF (no <br>).
    if "\n" in text:
        text = text.replace("\n", " ")

    # Explicit links: [text](url "title")
    m = _LINK_RE.search(text)
    if m:
        before = text[: m.start()]
        label = m.group(1)
        href = m.group(2)
        after = text[m.end() :]
        link_mark = {"type": "link", "attrs": {"href": href}}
        link_nodes = _with_mark(_parse_text_run(label), link_mark)
        return _parse_text_run(before) + link_nodes + _parse_text_run(after)

    # Autolinks: <https://...>
    m = _AUTOLINK_RE.search(text)
    if m:
        before = text[: m.start()]
        url = m.group(1)
        after = text[m.end() :]
        link_mark = {"type": "link", "attrs": {"href": url}}
        return [
            *_parse_text_run(before),
            {"type": "text", "text": url, "marks": [link_mark]},
            *_parse_text_run(after),
        ]

    # Strong (must come before em so ** doesn't match as two *).
    m = _STRONG_RE.search(text)
    if m:
        before = text[: m.start()]
        inner = m.group(2)
        after = text[m.end() :]
        return (
            _parse_text_run(before)
            + _with_mark(_parse_text_run(inner), {"type": "strong"})
            + _parse_text_run(after)
        )

    # Emphasis.
    m = _EM_RE.search(text)
    if m:
        before = text[: m.start()]
        inner = m.group(2)
        after = text[m.end() :]
        return (
            _parse_text_run(before)
            + _with_mark(_parse_text_run(inner), {"type": "em"})
            + _parse_text_run(after)
        )

    # Strikethrough.
    m = _STRIKE_RE.search(text)
    if m:
        before = text[: m.start()]
        inner = m.group(1)
        after = text[m.end() :]
        return (
            _parse_text_run(before)
            + _with_mark(_parse_text_run(inner), {"type": "strike"})
            + _parse_text_run(after)
        )

    # Plain text.
    return [{"type": "text", "text": text}] if text else []


def parse_inlines(text: str) -> list[dict]:
    """Parse inline Markdown into a list of ADF inline nodes."""
    out: list[dict] = []
    for kind, chunk in _split_codespans(text):
        if kind == "code":
            out.append({"type": "text", "text": chunk, "marks": [{"type": "code"}]})
        else:
            out.extend(_parse_text_run(chunk))
    # Merge adjacent text nodes with identical marks for tidiness.
    return _merge_adjacent_text(out)


def _merge_adjacent_text(nodes: list[dict]) -> list[dict]:
    out: list[dict] = []
    for n in nodes:
        if (
            out
            and n.get("type") == "text"
            and out[-1].get("type") == "text"
            and n.get("marks") == out[-1].get("marks")
        ):
            out[-1] = dict(out[-1])
            out[-1]["text"] = out[-1]["text"] + n["text"]
        else:
            out.append(n)
    return out


# ---------------------------------------------------------------------------
# Block parsing
# ---------------------------------------------------------------------------

_HEADING_RE = re.compile(r"^(#{1,6})[ \t]+(.+?)[ \t]*#*\s*$")
_HR_RE = re.compile(r"^[ \t]*(?:(?:-[ \t]*){3,}|(?:\*[ \t]*){3,}|(?:_[ \t]*){3,})\s*$")
_FENCE_RE = re.compile(
    r"^(?P<indent>[ \t]*)(?P<fence>`{3,}|~{3,})[ \t]*(?P<lang>\S*)?\s*$"
)
_UL_RE = re.compile(r"^(?P<indent>[ \t]*)(?P<marker>[-*+])[ \t]+(?P<rest>.*)$")
_OL_RE = re.compile(r"^(?P<indent>[ \t]*)(?P<num>\d+)[.)][ \t]+(?P<rest>.*)$")
_TASK_RE = re.compile(r"^\[(?P<mark>[ xX])\][ \t]+(?P<rest>.*)$")
_BLOCKQUOTE_RE = re.compile(r"^[ \t]*>[ \t]?(?P<rest>.*)$")
_CONTAINER_OPEN_RE = re.compile(
    r"^[ \t]*(?P<fence>:{3,})[ \t]*(?P<kind>[A-Za-z][\w-]*)[ \t]*(?P<args>.*?)\s*$"
)
_CONTAINER_CLOSE_RE = re.compile(r"^[ \t]*(?P<fence>:{3,})\s*$")
_PANEL_KINDS = {"info", "warning", "note", "success", "error"}
_TABLE_SEP_RE = re.compile(
    r"^[ \t]*\|?[ \t]*:?-{3,}:?[ \t]*(\|[ \t]*:?-{3,}:?[ \t]*)+\|?[ \t]*$"
)


def _indent_of(line: str) -> int:
    n = 0
    for ch in line:
        if ch == " ":
            n += 1
        elif ch == "\t":
            n += 4
        else:
            break
    return n


def _blank(line: str) -> bool:
    return line.strip() == ""


def markdown_to_adf(md: str) -> dict:
    """Top-level entry point. Returns an ADF document dict."""
    lines = md.splitlines()
    blocks = _parse_blocks(lines, 0, len(lines), base_indent=0)
    return {"version": 1, "type": "doc", "content": blocks}


def _parse_blocks(
    lines: list[str], start: int, end: int, base_indent: int
) -> list[dict]:
    """Parse lines[start:end] into ADF block nodes.

    `base_indent` is the indentation level the caller expects; content
    indented less than this belongs to an outer block.
    """
    out: list[dict] = []
    i = start
    while i < end:
        line = lines[i]
        if _blank(line):
            i += 1
            continue

        # Fenced code.
        fm = _FENCE_RE.match(line)
        if fm and _indent_of(line) >= base_indent:
            fence = fm.group("fence")
            lang = fm.group("lang") or ""
            indent = _indent_of(line)
            j = i + 1
            code_lines: list[str] = []
            while j < end:
                if (
                    lines[j].lstrip().startswith(fence[0] * len(fence))
                    and lines[j].lstrip()[: len(fence)] == fence
                ):
                    break
                # Strip leading indent to match the fence.
                stripped = lines[j]
                if stripped.startswith(" " * indent):
                    stripped = stripped[indent:]
                code_lines.append(stripped)
                j += 1
            code_node: dict = {
                "type": "codeBlock",
                "content": [{"type": "text", "text": "\n".join(code_lines)}]
                if code_lines
                else [],
            }
            if lang:
                code_node["attrs"] = {"language": lang}
            out.append(code_node)
            i = j + 1 if j < end else j
            continue

        # Heading.
        hm = _HEADING_RE.match(line)
        if hm and _indent_of(line) >= base_indent:
            level = len(hm.group(1))
            text = hm.group(2)
            out.append(
                {
                    "type": "heading",
                    "attrs": {"level": level},
                    "content": parse_inlines(text),
                }
            )
            i += 1
            continue

        # Horizontal rule.
        if _HR_RE.match(line):
            out.append({"type": "rule"})
            i += 1
            continue

        # Table: header line followed by separator on next line.
        if "|" in line and i + 1 < end and _TABLE_SEP_RE.match(lines[i + 1]):
            table_node, consumed = _parse_table(lines, i, end)
            out.append(table_node)
            i += consumed
            continue

        # Fenced container (:::panel / :::expand / :::quote).
        cm = _CONTAINER_OPEN_RE.match(line)
        if cm and cm.group("kind").lower() in {"panel", "expand", "quote"}:
            container_node, consumed = _parse_container(lines, i, end)
            if container_node is not None:
                out.append(container_node)
                i += consumed
                continue
            # Fall through if the container failed to parse (no close fence);
            # treat the opener as a plain paragraph.

        # Blockquote.
        if _BLOCKQUOTE_RE.match(line):
            bq_node, consumed = _parse_blockquote(lines, i, end)
            out.append(bq_node)
            i += consumed
            continue

        # List (unordered / ordered / task).
        if _UL_RE.match(line) or _OL_RE.match(line):
            list_node, consumed = _parse_list(lines, i, end)
            out.append(list_node)
            i += consumed
            continue

        # Paragraph: collect until blank or another block-start.
        para_lines: list[str] = [line]
        j = i + 1
        while j < end:
            nxt = lines[j]
            if _blank(nxt):
                break
            if (
                _HEADING_RE.match(nxt)
                or _HR_RE.match(nxt)
                or _FENCE_RE.match(nxt)
                or _BLOCKQUOTE_RE.match(nxt)
                or _UL_RE.match(nxt)
                or _OL_RE.match(nxt)
            ):
                break
            if "|" in nxt and j + 1 < end and _TABLE_SEP_RE.match(lines[j + 1]):
                break
            para_lines.append(nxt)
            j += 1
        content = parse_inlines("\n".join(para_lines))
        if content:
            out.append({"type": "paragraph", "content": content})
        i = j
    return out


def _parse_container(lines: list[str], start: int, end: int):
    """Parse a fenced container starting at `start`.

    Supports three kinds:
      :::panel <kind>             -> ADF panel (panelType attr)
      :::expand <title>           -> ADF expand (title attr)
      :::quote                    -> ADF blockquote

    Containers close with a `:::` line whose colon count matches the
    opener (or is at least 3). Nesting works because we track the
    depth of unmatched openers of the *same fence length* inside.

    Returns (node, lines_consumed) or (None, 0) if no closing fence was
    found (caller falls back to treating the line as a paragraph).
    """
    om = _CONTAINER_OPEN_RE.match(lines[start])
    if not om:
        return None, 0
    fence = om.group("fence")
    kind = om.group("kind").lower()
    args = (om.group("args") or "").strip()

    # Find the matching close: a line that is exactly `fence` (or longer
    # run of colons), accounting for nested containers of the same kind.
    depth = 1
    j = start + 1
    while j < end:
        ln = lines[j]
        cm = _CONTAINER_CLOSE_RE.match(ln)
        if cm and len(cm.group("fence")) >= len(fence):
            # Heuristic: a bare `:::` line is a close unless we just saw
            # an opener that hasn't been closed yet. We've been tracking
            # depth, so just decrement.
            depth -= 1
            if depth == 0:
                break
            j += 1
            continue
        nm = _CONTAINER_OPEN_RE.match(ln)
        if nm and nm.group("kind").lower() in {"panel", "expand", "quote"} \
                and len(nm.group("fence")) >= len(fence):
            depth += 1
        j += 1

    if j >= end:
        # No closing fence found.
        return None, 0

    inner_lines = lines[start + 1 : j]
    inner_blocks = _parse_blocks(inner_lines, 0, len(inner_lines), base_indent=0)

    if kind == "panel":
        panel_kind = args.lower() if args else "info"
        if panel_kind not in _PANEL_KINDS:
            panel_kind = "info"
        # ADF panel content must be paragraphs/lists/headings; we pass
        # through whatever _parse_blocks produced (it already emits
        # valid block nodes).
        node = {
            "type": "panel",
            "attrs": {"panelType": panel_kind},
            "content": inner_blocks or [{"type": "paragraph", "content": []}],
        }
    elif kind == "expand":
        # Strip surrounding quotes from the title argument if present.
        title = args
        if (
            len(title) >= 2
            and title[0] in ("\"", "'")
            and title[-1] == title[0]
        ):
            title = title[1:-1]
        node = {
            "type": "expand",
            "attrs": {"title": title or "Details"},
            "content": inner_blocks or [{"type": "paragraph", "content": []}],
        }
    else:  # quote
        node = {
            "type": "blockquote",
            "content": inner_blocks or [{"type": "paragraph", "content": []}],
        }

    return node, (j - start) + 1


def _parse_blockquote(lines: list[str], start: int, end: int):
    """Collect consecutive blockquote lines, strip the leading '>', and
    recursively parse them as block content."""
    inner: list[str] = []
    i = start
    while i < end:
        m = _BLOCKQUOTE_RE.match(lines[i])
        if m:
            inner.append(m.group("rest"))
            i += 1
        elif (
            not _blank(lines[i])
            and inner
            and not lines[i].lstrip().startswith(("-", "*", "+", "#", "`", ">"))
            and not _HR_RE.match(lines[i])
        ):
            # Lazy continuation: unmarked line continues the blockquote.
            inner.append(lines[i])
            i += 1
        else:
            break
    blocks = _parse_blocks(inner, 0, len(inner), base_indent=0)
    return {"type": "blockquote", "content": blocks}, i - start


def _parse_list(lines: list[str], start: int, end: int, _base_indent: int = 0):
    """Parse a (possibly nested) list starting at `start`.

    Returns (list_node, lines_consumed). Handles mixing -> no: if the
    first item is `-` we stay in a bulletList until dedent/blank;
    numbered lists stay orderedList. A task list (`- [ ]`) promotes the
    whole list to a taskList.

    The `_base_indent` parameter is accepted for symmetry with
    `_parse_blocks` but isn't consulted directly -- the first item's
    own indent establishes the baseline (`marker_indent`).
    """
    first = lines[start]
    ul = _UL_RE.match(first)
    ol = _OL_RE.match(first)
    assert ul or ol
    is_ordered = bool(ol)
    marker_indent = _indent_of(first)

    # Peek to see if this is a task list (first item starts with `[ ]`).
    if ul:
        first_rest = ul.group("rest")
        is_task_list = bool(_TASK_RE.match(first_rest))
    else:
        is_task_list = False

    items: list[list[str]] = []  # each item: list of raw lines
    i = start
    while i < end:
        line = lines[i]
        if _blank(line):
            # Blank line: might end the list or be an internal blank.
            # Look ahead: if the next non-blank is a list item at the
            # same indent, include the blank as part of the previous item.
            j = i + 1
            while j < end and _blank(lines[j]):
                j += 1
            if j >= end:
                break
            nxt = lines[j]
            nxt_ul = _UL_RE.match(nxt)
            nxt_ol = _OL_RE.match(nxt)
            if (nxt_ul or nxt_ol) and _indent_of(nxt) == marker_indent:
                # Continues the list.
                items[-1].append("")  # preserve blank as paragraph break
                i = j
                continue
            if _indent_of(nxt) > marker_indent and items:
                # Continues a nested block inside the current item.
                items[-1].append("")
                i = j
                continue
            break

        ind = _indent_of(line)
        m_ul = _UL_RE.match(line)
        m_ol = _OL_RE.match(line)
        is_marker = (m_ul and ind == marker_indent) or (m_ol and ind == marker_indent)
        if is_marker:
            m = m_ul or m_ol
            if (is_ordered and not m_ol) or (not is_ordered and not m_ul):
                # Different list kind at the same indent -> new list.
                break
            items.append([m.group("rest")])
            i += 1
            continue
        if ind > marker_indent and items:
            # Indented continuation of the current item.
            items[-1].append(
                line[marker_indent + 2 :]
                if line.startswith(" " * (marker_indent + 2))
                else line.lstrip()
            )
            i += 1
            continue
        break

    # Build ADF.
    list_items: list[dict] = []
    for raw in items:
        if is_task_list:
            # First line: [ ] or [x]; rest is content.
            tm = _TASK_RE.match(raw[0])
            if tm:
                state = "DONE" if tm.group("mark").lower() == "x" else "TODO"
                item_lines = [tm.group("rest"), *raw[1:]]
            else:
                state = "TODO"
                item_lines = raw
            inline = parse_inlines("\n".join(item_lines).rstrip())
            list_items.append(
                {
                    "type": "taskItem",
                    "attrs": {"localId": f"task-{len(list_items)}", "state": state},
                    "content": inline,
                }
            )
        else:
            # Parse the item's lines as a mini-document so that nested
            # lists / paragraphs / code blocks all work.
            sub_blocks = _parse_blocks(raw, 0, len(raw), base_indent=0)
            # Per ADF, listItem content must start with a block node.
            # If we got only inline content (shouldn't happen given
            # _parse_blocks), wrap in paragraph.
            if not sub_blocks:
                sub_blocks = [{"type": "paragraph", "content": []}]
            list_items.append({"type": "listItem", "content": sub_blocks})

    if is_task_list:
        node = {
            "type": "taskList",
            "attrs": {"localId": f"tasklist-{id(items)}"},
            "content": list_items,
        }
    elif is_ordered:
        node = {"type": "orderedList", "content": list_items}
    else:
        node = {"type": "bulletList", "content": list_items}

    return node, i - start


def _parse_table(lines: list[str], start: int, end: int):
    """Parse a GFM pipe table: header row, separator, then body rows."""
    header_line = lines[start]
    sep_line = lines[start + 1]
    header_cells = _split_table_row(header_line)
    # Parse alignment from separator.
    alignments: list[str | None] = []
    for raw_cell in _split_table_row(sep_line):
        cell = raw_cell.strip()
        left = cell.startswith(":")
        right = cell.endswith(":")
        if left and right:
            alignments.append("center")
        elif right:
            alignments.append("right")
        elif left:
            alignments.append("left")
        else:
            alignments.append(None)

    rows: list[list[str]] = []
    i = start + 2
    while i < end:
        line = lines[i]
        if _blank(line) or "|" not in line:
            break
        rows.append(_split_table_row(line))
        i += 1

    def _cell_node(cell_text: str, header: bool, align: str | None) -> dict:
        node = {
            "type": "tableHeader" if header else "tableCell",
            "content": [
                {
                    "type": "paragraph",
                    "content": parse_inlines(cell_text.strip()),
                }
            ],
        }
        if align:
            node["attrs"] = {"colwidth": None}
            # ADF doesn't use a simple 'align' on cells directly; alignment
            # marks go on inline text. We skip alignment rather than emit
            # invalid attrs.
            del node["attrs"]
        return node

    content: list[dict] = []
    # Header row.
    content.append(
        {
            "type": "tableRow",
            "content": [
                _cell_node(h, True, alignments[idx] if idx < len(alignments) else None)
                for idx, h in enumerate(header_cells)
            ],
        }
    )
    # Body rows.
    for raw_row in rows:
        # Pad or truncate to header width.
        row = list(raw_row)
        while len(row) < len(header_cells):
            row.append("")
        row = row[: len(header_cells)]
        content.append(
            {
                "type": "tableRow",
                "content": [
                    _cell_node(
                        c, False, alignments[idx] if idx < len(alignments) else None
                    )
                    for idx, c in enumerate(row)
                ],
            }
        )

    return {
        "type": "table",
        "attrs": {"isNumberColumnEnabled": False, "layout": "default"},
        "content": content,
    }, i - start


def _split_table_row(line: str) -> list[str]:
    """Split a pipe-table row into cells, respecting escaped pipes."""
    # Strip leading/trailing pipe.
    s = line.strip().removeprefix("|").removesuffix("|")
    # Split on unescaped pipes.
    cells: list[str] = []
    buf = []
    i = 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s) and s[i + 1] == "|":
            buf.append("|")
            i += 2
        elif s[i] == "|":
            cells.append("".join(buf))
            buf = []
            i += 1
        else:
            buf.append(s[i])
            i += 1
    cells.append("".join(buf))
    return cells


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _cli(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Convert Markdown to ADF JSON for Jira Cloud."
    )
    ap.add_argument("input", nargs="?", help="Markdown file (default: stdin).")
    ap.add_argument("-o", "--out", help="Write JSON to this file (default: stdout).")
    ap.add_argument(
        "--indent", type=int, default=2, help="JSON indent (0 for compact)."
    )
    args = ap.parse_args(argv)

    if args.input and args.input != "-":
        with open(args.input, encoding="utf-8") as f:
            md = f.read()
    else:
        md = sys.stdin.read()

    adf = markdown_to_adf(md)
    indent = args.indent if args.indent > 0 else None
    payload = json.dumps(adf, indent=indent)

    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(payload)
    else:
        print(payload)
    return 0


if __name__ == "__main__":
    sys.exit(_cli(sys.argv[1:]))
