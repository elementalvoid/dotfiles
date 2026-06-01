# pi webfetch extension

Fetches a URL and returns clean Markdown using Mozilla Readability (the same engine as Firefox Reader Mode). No system dependencies — all packages are bundled locally.

## Install

```bash
cp -r webfetch ~/.pi/agent/extensions/
cd ~/.pi/agent/extensions/webfetch
npm install
```

Then in pi: `/reload`

## Usage

**As an LLM tool** — pi will call it automatically when you ask it to read a URL:
> "Summarise https://example.com/article"

**As a command:**
```
/webfetch https://example.com/article
```

Fetches the page, extracts the article body, and injects the Markdown into the conversation so you can ask questions about it.

## GitHub URLs

The extension instructs the LLM to prefer `gh` CLI over webfetch for GitHub content:

| Content | Command |
|---|---|
| Repo overview | `gh repo view OWNER/REPO` |
| Single file | `gh api repos/OWNER/REPO/contents/PATH --jq .content \| base64 -d` |
| Multiple files | `gh repo clone OWNER/REPO` then use the read tool |
| Issues | `gh issue view NUMBER --repo OWNER/REPO` |
| Pull requests | `gh pr view NUMBER --repo OWNER/REPO` |

## Stack

| Role | Package |
|---|---|
| HTTP fetch | `node:https` / `node:http` (Node built-in) |
| DOM | `linkedom` — pure JS, no native bindings |
| Content extraction | `@mozilla/readability` — Firefox Reader Mode algorithm |
| HTML → Markdown | `turndown` + `turndown-plugin-gfm` |
