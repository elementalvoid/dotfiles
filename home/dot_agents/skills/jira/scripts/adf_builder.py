"""ADF (Atlassian Document Format) builder helpers.

Jira Cloud's REST API (and therefore `acli jira workitem edit/create
--description-file`) wants rich text as ADF JSON, not Markdown and not
wiki markup. Hand-writing ADF is tedious; these helpers compose it from
small pieces so you can write something close to natural prose in Python
and get valid ADF out the other end.

Typical usage:

    from adf_builder import doc, h, para, bullets, b, i, code, link, write_adf

    body = doc(
        h(2, "Context"),
        para("We need ", b("provenance"), " for every deploy."),
        h(2, "Scope"),
        bullets([
            "Kubernetes",
            "Lambda via EventBridge",
            [para("Databricks medallion:"),
             bullets(["bronze", "silver", "gold"])],
        ]),
        para("Prior art: ", link("the drive folder",
             "https://drive.google.com/drive/folders/xyz")),
    )
    write_adf(body, "/tmp/description.json")

Then:

    acli jira workitem edit --key KEY-1 \\
        --description-file /tmp/description.json --yes
"""

from __future__ import annotations
import json
from typing import Iterable, Union

Node = dict
Inline = Union[str, Node]
Block = Union[Node, Iterable[Node]]


# ---------- inline nodes (text + marks) ----------


def text(s: str, marks: list[str] | None = None) -> Node:
    """Plain text. `marks` is a list of mark type names like ['strong', 'em']."""
    n: Node = {"type": "text", "text": s}
    if marks:
        n["marks"] = [{"type": m} for m in marks]
    return n


def b(s: str) -> Node:
    """Bold."""
    return text(s, ["strong"])


def i(s: str) -> Node:
    """Italic."""
    return text(s, ["em"])


def code(s: str) -> Node:
    """Inline code."""
    return text(s, ["code"])


def strike(s: str) -> Node:
    return text(s, ["strike"])


def link(label: str, href: str) -> Node:
    """Hyperlink with an inline label."""
    return {
        "type": "text",
        "text": label,
        "marks": [{"type": "link", "attrs": {"href": href}}],
    }


def _inlines(items) -> list[Node]:
    """Coerce strings to text nodes; pass through dict nodes."""
    out = []
    for x in items:
        out.append(text(x) if isinstance(x, str) else x)
    return out


# ---------- block nodes ----------


def para(*inlines) -> Node:
    """Paragraph. Accepts strings and inline nodes, mixed."""
    return {"type": "paragraph", "content": _inlines(inlines)}


def h(level: int, s: str) -> Node:
    """Heading, level 1-6."""
    if not 1 <= level <= 6:
        raise ValueError("heading level must be 1-6")
    return {"type": "heading", "attrs": {"level": level}, "content": [text(s)]}


def bullets(items) -> Node:
    """Bullet list.

    Each item may be:
      - a string (wrapped in a paragraph),
      - an inline/block node dict (used as the sole child of the listItem),
      - a list of block nodes (for multi-block list items, e.g. a paragraph
        followed by a nested bulletList).
    """
    list_items = []
    for it in items:
        if isinstance(it, list):
            list_items.append({"type": "listItem", "content": it})
        elif isinstance(it, dict):
            # If caller handed us a paragraph/heading/list, use directly.
            # If they handed us an inline text node, wrap it in a paragraph.
            if it.get("type") in {
                "paragraph",
                "heading",
                "bulletList",
                "orderedList",
                "codeBlock",
                "blockquote",
            }:
                list_items.append({"type": "listItem", "content": [it]})
            else:
                list_items.append({"type": "listItem", "content": [para(it)]})
        else:
            list_items.append({"type": "listItem", "content": [para(it)]})
    return {"type": "bulletList", "content": list_items}


def numbered(items) -> Node:
    """Ordered list. Same item semantics as `bullets`."""
    n = bullets(items)
    n["type"] = "orderedList"
    return n


def quote(*blocks: Node) -> Node:
    """Blockquote containing one or more block nodes."""
    return {"type": "blockquote", "content": list(blocks)}


def code_block(source: str, language: str | None = None) -> Node:
    """Fenced code block. Language is optional (e.g. 'python', 'bash')."""
    node: Node = {
        "type": "codeBlock",
        "content": [text(source)],
    }
    if language:
        node["attrs"] = {"language": language}
    return node


def rule() -> Node:
    """Horizontal rule."""
    return {"type": "rule"}


_PANEL_KINDS = {"info", "warning", "note", "success", "error"}


def panel(kind: str, *blocks: Node) -> Node:
    """ADF panel (admonition box). `kind` is one of:
    info, warning, note, success, error.

    Falls back to 'info' if an unknown kind is passed.
    """
    k = kind.lower() if isinstance(kind, str) else "info"
    if k not in _PANEL_KINDS:
        k = "info"
    return {
        "type": "panel",
        "attrs": {"panelType": k},
        "content": list(blocks) or [{"type": "paragraph", "content": []}],
    }


def expand(title: str, *blocks: Node) -> Node:
    """ADF expand (collapsible section). `title` is shown in the
    collapsed state."""
    return {
        "type": "expand",
        "attrs": {"title": title or "Details"},
        "content": list(blocks) or [{"type": "paragraph", "content": []}],
    }


# ---------- document ----------


def doc(*blocks: Node) -> Node:
    """Top-level ADF document."""
    return {"version": 1, "type": "doc", "content": list(blocks)}


def write_adf(document: Node, path: str) -> str:
    """Serialize to disk. Returns the path for convenience."""
    with open(path, "w", encoding="utf-8") as f:
        json.dump(document, f, indent=2)
    return path


if __name__ == "__main__":
    # Small smoke test when run directly.
    sample = doc(
        h(1, "Demo"),
        para(
            "This is ",
            b("bold"),
            " and ",
            i("italic"),
            " and ",
            code("inline code"),
            ".",
        ),
        h(2, "A list"),
        bullets(
            [
                "plain item",
                para(b("bold-led"), " item with trailing text"),
                [para("nested:"), bullets(["a", "b"])],
            ]
        ),
        para(
            "See ",
            link(
                "ADF docs",
                "https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/",
            ),
            ".",
        ),
        code_block("print('hi')", "python"),
    )
    print(json.dumps(sample, indent=2))
