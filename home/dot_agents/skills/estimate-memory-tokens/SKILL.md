---
name: estemate-memory-tokens
description: Estimate token count for all agent memory/instruction files
model: sonnet
allowed-tools: Glob, Bash
---

Find all agents memory and instruction files in the current project using filesystem globbing (not git). The files to find are:

- `**/CLAUDE.md` and `**/CLAUDE.local.md` (project root and any subdirectories, including `.claude`)
- `**/AGENTS.md` (project root and any subdirectories)
- `.claude/rules/**/*.md`

Also include user-level files:

- `~/.claude/CLAUDE.md`
- `~/.claude/rules/**/*.md`

For each file found, count its tokens using tiktoken with the `cl100k_base` encoding.

Run the counting script inline with `uv run --with tiktoken` — do NOT create a venv or pip install.

Output per-file token counts and a total, like:

```text
    65  ~/.claude/CLAUDE.md
   332  .claude/CLAUDE.md
   126  .claude/rules/ci-enforcement.md
   523  TOTAL
```

Display this to the user as a table, make it pretty.

Note: These are estimates using cl100k_base, the closest tiktoken approximation to Claude's proprietary tokenizer. Expect ~10-20% undercount vs actual Claude token usage.
