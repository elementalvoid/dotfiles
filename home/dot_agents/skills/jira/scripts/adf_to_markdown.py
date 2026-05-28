"""ADF (Atlassian Document Format) -> Markdown converter.

Reverse of `adf_from_markdown.py`. Takes the ADF JSON that comes back
from `acli jira workitem view --json` (under `fields.description`,
`fields.comment.comments[*].body`, etc.) and produces GitHub-Flavored
Markdown.

Typical use:

    acli jira workitem view ENP-44 --json \\
        | python3 adf_to_markdown.py --field description > plan.md

Or as a library:

    from adf_to_markdown import adf_to_markdown
    md = adf_to_markdown(adf_doc)

The output is intentionally lossy where Markdown lacks a native
equivalent (panels, expand sections, status pills, colored text,
mentions, attached media). Everything that *can* round-trip through
`adf_from_markdown.py` does: headings, paragraphs, bullet/ordered/task
lists, code blocks, blockquotes, tables, rules, and the standard inline
marks (bold, italic, code, strike, link).

Non-round-trippable constructs are represented with readable Markdown
fallbacks and (where useful) an HTML comment noting the original type,
so a human reading the file can tell they're looking at a lossy
rendering.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any

# Characters that are ambiguous *anywhere* in a Markdown text run and
# therefore need escaping to render as literal characters. We keep this
# set deliberately narrow -- over-escaping produces ugly output and
# compounds on round-trip (e.g. '-' -> '\-' -> '\\-' -> ...).
#
# Deliberately NOT escaped: '-', '+', '(', ')', '!', '#', '>', '|',
# '{', '}', '<'. These are only meaningful at line start or in specific
# structural contexts; escaping them in running text is noisy and
# rarely prevents actual misparses.
_MD_ESCAPE_RE = re.compile(r"([\\`*_~\[\]])")


def _escape_text(s: str) -> str:
    """Escape Markdown meta-characters in a text run.

    Narrow by design: only characters that are ambiguous in running
    text (backslash, backtick, emphasis markers, tilde, square
    brackets). Characters like '-', '(', ')', '+', '#', '>', '|' are
    only meaningful at line starts or in specific structural contexts,
    so escaping them mid-text is noisy and compounds on round-trip.
    """
    return _MD_ESCAPE_RE.sub(r"\\\1", s)


# ---------------------------------------------------------------------------
# Inline rendering
# ---------------------------------------------------------------------------


def _render_marks(text: str, marks: list[dict]) -> str:
    """Wrap `text` in Markdown syntax for each mark in `marks`.

    Order matters for readability: we put code innermost (because
    backticks swallow other formatting) and link outermost.
    """
    mark_types = {m.get("type"): m for m in marks}

    # code is innermost -- no other marks render inside a code span
    if "code" in mark_types:
        # If text contains backticks, use a longer fence so they don't
        # terminate the span prematurely.
        max_run = 0
        run = 0
        for ch in text:
            if ch == "`":
                run += 1
                max_run = max(max_run, run)
            else:
                run = 0
        fence = "`" * (max_run + 1)
        pad = " " if text.startswith("`") or text.endswith("`") else ""
        text = f"{fence}{pad}{text}{pad}{fence}"
        # Code spans strip formatting marks; skip further wrapping.
        mark_types = {k: v for k, v in mark_types.items() if k == "link"}
    else:
        text = _escape_text(text)

    if "strike" in mark_types:
        text = f"~~{text}~~"
    if "em" in mark_types:
        text = f"*{text}*"
    if "strong" in mark_types:
        text = f"**{text}**"
    if "underline" in mark_types:
        # No native Markdown underline; use HTML.
        text = f"<u>{text}</u>"
    if "subsup" in mark_types:
        kind = mark_types["subsup"].get("attrs", {}).get("type", "sub")
        tag = "sup" if kind == "sup" else "sub"
        text = f"<{tag}>{text}</{tag}>"
    if "textColor" in mark_types:
        color = mark_types["textColor"].get("attrs", {}).get("color", "")
        # Best-effort fallback; Markdown has no native color.
        if color:
            text = f'<span style="color:{color}">{text}</span>'
    if "link" in mark_types:
        href = mark_types["link"].get("attrs", {}).get("href", "")
        if href:
            text = f"[{text}]({href})"

    return text


def _render_inline(node: dict) -> str:
    t = node.get("type")
    if t == "text":
        return _render_marks(node.get("text", ""), node.get("marks") or [])
    if t == "hardBreak":
        # Two trailing spaces + newline is Markdown's hard break.
        return "  \n"
    if t == "mention":
        attrs = node.get("attrs", {})
        label = attrs.get("text") or f"@{attrs.get('id', 'unknown')}"
        return _escape_text(label)
    if t == "emoji":
        attrs = node.get("attrs", {})
        # Prefer the rendered text char if provided; fallback to shortName.
        return attrs.get("text") or attrs.get("shortName", "")
    if t == "date":
        ts = node.get("attrs", {}).get("timestamp")
        if ts is None:
            return ""
        try:
            import datetime as _dt

            dt = _dt.datetime.fromtimestamp(
                int(ts) / 1000,
                tz=_dt.timezone.utc,
            )
            return dt.strftime("%Y-%m-%d")
        except (TypeError, ValueError, OSError, OverflowError):
            return str(ts)
    if t == "status":
        attrs = node.get("attrs", {})
        text = attrs.get("text", "STATUS")
        return f"`[{text}]`"
    if t == "inlineCard":
        url = node.get("attrs", {}).get("url", "")
        return f"<{url}>" if url else ""
    if t == "mediaInline":
        attrs = node.get("attrs", {})
        name = attrs.get("collection") or attrs.get("id", "media")
        return f"<!-- mediaInline: {name} -->"
    # Unknown inline node -- surface type as a comment for debuggability.
    return f"<!-- inline:{t} -->"


def _render_inlines(nodes: list[dict] | None) -> str:
    if not nodes:
        return ""
    return "".join(_render_inline(n) for n in nodes)


# ---------------------------------------------------------------------------
# Block rendering
# ---------------------------------------------------------------------------


def _indent(text: str, prefix: str) -> str:
    """Prefix every line of `text` with `prefix`."""
    return "\n".join(
        (prefix + ln) if ln else prefix.rstrip() for ln in text.splitlines()
    )


def _render_block(node: dict, list_depth: int = 0) -> str:
    t = node.get("type")
    content = node.get("content") or []
    attrs = node.get("attrs") or {}

    if t == "paragraph":
        return _render_inlines(content)

    if t == "heading":
        level = int(attrs.get("level", 1))
        level = max(1, min(6, level))
        return "#" * level + " " + _render_inlines(content)

    if t == "bulletList":
        return _render_list(content, ordered=False, depth=list_depth)

    if t == "orderedList":
        return _render_list(
            content, ordered=True, depth=list_depth, start=int(attrs.get("order", 1))
        )

    if t == "taskList":
        return _render_task_list(content, depth=list_depth)

    if t == "codeBlock":
        lang = attrs.get("language", "") or ""
        # codeBlock content is a list of text nodes; concatenate raw text.
        raw = "".join(c.get("text", "") for c in content if c.get("type") == "text")
        # Choose a fence that's longer than the longest backtick run inside.
        max_run = 0
        run = 0
        for ch in raw:
            if ch == "`":
                run += 1
                max_run = max(max_run, run)
            else:
                run = 0
        fence = "`" * max(3, max_run + 1)
        return f"{fence}{lang}\n{raw}\n{fence}"

    if t == "blockquote":
        inner = _render_blocks(content, list_depth=list_depth)
        return _indent(inner, "> ")

    if t == "rule":
        return "---"

    if t == "panel":
        kind = attrs.get("panelType", "info").upper()
        inner = _render_blocks(content, list_depth=list_depth)
        header = f"> **[{kind}]**"
        return header + "\n" + _indent(inner, "> ")

    if t in {"expand", "nestedExpand"}:
        title = attrs.get("title", "Details")
        inner = _render_blocks(content, list_depth=list_depth)
        return f"<details>\n<summary>{title}</summary>\n\n{inner}\n\n</details>"

    if t == "table":
        return _render_table(content)

    if t in {"mediaSingle", "mediaGroup"}:
        # Each child `media` has an attachment id; we can't resolve it
        # to a URL without an API call, so note the presence.
        ids = []
        for c in content:
            if c.get("type") == "media":
                mid = c.get("attrs", {}).get("id")
                if mid:
                    ids.append(mid)
        return ("<!-- media: " + ", ".join(ids) + " -->") if ids else "<!-- media -->"

    if t == "rule":
        return "---"

    # Unknown block -- surface for debuggability.
    inner = _render_blocks(content, list_depth=list_depth) if content else ""
    return f"<!-- adf block:{t} -->\n{inner}".rstrip()


def _render_blocks(blocks: list[dict], list_depth: int = 0) -> str:
    """Render a sequence of block nodes, separated by blank lines."""
    parts = [_render_block(b, list_depth=list_depth) for b in blocks]
    parts = [p for p in parts if p != ""]
    return "\n\n".join(parts)


def _render_list(items: list[dict], ordered: bool, depth: int, start: int = 1) -> str:
    """Render a bulletList or orderedList."""
    out_lines: list[str] = []
    indent = "  " * depth
    for i, item in enumerate(items):
        if item.get("type") != "listItem":
            continue
        sub_blocks = item.get("content") or []
        # Render each block of the item.
        rendered = [_render_block(b, list_depth=depth + 1) for b in sub_blocks]
        rendered = [r for r in rendered if r != ""]
        if not rendered:
            rendered = [""]

        marker = f"{start + i}." if ordered else "-"
        # First line gets the marker; subsequent lines get a hanging indent.
        first = rendered[0]
        first_lines = first.splitlines() or [""]
        out_lines.append(f"{indent}{marker} {first_lines[0]}")
        hang = " " * (len(marker) + 1)
        for extra in first_lines[1:]:
            out_lines.append(f"{indent}{hang}{extra}")

        for block_text in rendered[1:]:
            # Blank line between sub-blocks within a list item.
            out_lines.append("")
            for ln in block_text.splitlines() or [""]:
                out_lines.append(f"{indent}{hang}{ln}")

    return "\n".join(out_lines)


def _render_task_list(items: list[dict], depth: int) -> str:
    out = []
    indent = "  " * depth
    for item in items:
        if item.get("type") != "taskItem":
            continue
        state = item.get("attrs", {}).get("state", "TODO").upper()
        box = "[x]" if state == "DONE" else "[ ]"
        inline = _render_inlines(item.get("content") or [])
        out.append(f"{indent}- {box} {inline}")
    return "\n".join(out)


def _render_table(rows: list[dict]) -> str:
    """Render an ADF table as a GFM pipe table.

    The first tableRow is treated as the header if any of its cells are
    `tableHeader`; otherwise we synthesize an empty-looking header row
    to keep the output valid GFM.
    """
    if not rows:
        return ""

    def cells(row: dict) -> list[tuple[str, bool]]:
        out = []
        for c in row.get("content", []):
            ctype = c.get("type")
            if ctype not in ("tableCell", "tableHeader"):
                continue
            # Each cell's content is a list of blocks. For Markdown
            # compatibility, flatten to a single line by joining block
            # renderings with " / " and stripping newlines.
            inner_blocks = c.get("content", [])
            parts = [_render_block(b).replace("\n", " ") for b in inner_blocks]
            text = " / ".join(p for p in parts if p)
            out.append((text, ctype == "tableHeader"))
        return out

    first = cells(rows[0])
    is_header_row = any(h for _, h in first) if first else False

    if is_header_row:
        header = [t for t, _ in first]
        body_rows = rows[1:]
    else:
        header = [""] * len(first)
        body_rows = rows

    widths = [max(3, len(h)) for h in header]
    body = []
    for r in body_rows:
        row = [t for t, _ in cells(r)]
        while len(row) < len(header):
            row.append("")
        row = row[: len(header)]
        body.append(row)
        for i, t in enumerate(row):
            widths[i] = max(widths[i], len(t))

    def row_str(cells: list[str]) -> str:
        padded = [c.ljust(widths[i]) for i, c in enumerate(cells)]
        return "| " + " | ".join(padded) + " |"

    lines = [
        row_str(header),
        "| " + " | ".join("-" * widths[i] for i in range(len(header))) + " |",
    ]
    lines.extend(row_str(r) for r in body)
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Top-level + CLI
# ---------------------------------------------------------------------------


def adf_to_markdown(doc: dict) -> str:
    """Convert an ADF document (the {version, type:doc, content} dict) to
    Markdown. Accepts either a doc node or a single block node.
    """
    if not isinstance(doc, dict):
        raise TypeError(f"Expected ADF dict, got {type(doc).__name__}")
    if doc.get("type") == "doc":
        return _render_blocks(doc.get("content") or [])
    # Allow passing a single block as a convenience.
    return _render_block(doc)


def _extract_from_view_json(payload: Any, field: str) -> dict | None:
    """Pluck a description/ADF document out of `acli view --json` output.

    Handles:
      - the full response dict with `fields.<field>`
      - a bare ADF doc
      - the field value directly
    """
    if isinstance(payload, dict):
        if payload.get("type") == "doc":
            return payload
        fields = payload.get("fields")
        if isinstance(fields, dict) and field in fields:
            val = fields[field]
            if isinstance(val, dict) and val.get("type") == "doc":
                return val
            return None
        if field in payload:
            val = payload[field]
            if isinstance(val, dict) and val.get("type") == "doc":
                return val
    return None


def _cli(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Convert ADF JSON to Markdown.")
    ap.add_argument(
        "input",
        nargs="?",
        help="ADF JSON file (default: stdin). May be a bare "
        "ADF document or the full response from "
        "`acli jira workitem view --json`.",
    )
    ap.add_argument(
        "-o", "--out", help="Write Markdown to this file (default: stdout)."
    )
    ap.add_argument(
        "--field",
        default="description",
        help="When the input is a full view response, pull "
        "this field from `fields` (default: description). "
        "Ignored for bare ADF docs.",
    )
    args = ap.parse_args(argv)

    if args.input and args.input != "-":
        with open(args.input, encoding="utf-8") as f:
            raw = f.read()
    else:
        raw = sys.stdin.read()

    payload = json.loads(raw)
    doc = _extract_from_view_json(payload, args.field)
    if doc is None:
        print(
            f"error: could not find ADF document "
            f"(looked for fields.{args.field} or a bare doc).",
            file=sys.stderr,
        )
        return 2

    md = adf_to_markdown(doc)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(md)
            if not md.endswith("\n"):
                f.write("\n")
    else:
        print(md)
    return 0


if __name__ == "__main__":
    sys.exit(_cli(sys.argv[1:]))
