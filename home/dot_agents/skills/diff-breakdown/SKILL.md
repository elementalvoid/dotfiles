---
name: diff-breakdown
description: Categorize a git diff's line counts by meaningful change type and produce a compact summary table. Use when someone asks to break down a large diff, wants to contextualize a PR's line count ("how much of this is tests?", "what's the real code change?"), is preparing a PR description, or has just opened/updated a PR and wants to add a change summary. Also use when someone says a PR is "large" or the add/remove numbers look intimidating.
---

# Diff Breakdown

Produce a categorized line-count summary that helps reviewers understand *why* a diff is the size it is. The categories are discovered from the diff itself — never assumed in advance.

## Workflow

### 1. Get the raw diff stats

```bash
git diff <base>...HEAD --numstat
```

Default base is `main`; fall back to `master`; accept an explicit `--base` flag.

### 2. Study the file list *and* commit messages before categorizing

Fetch both signals before assigning a single file:

```bash
git log <base>...HEAD --oneline
```

Read the file paths and the commit log together and ask:

- **What kinds of things are actually changing?** Read the file paths as a set. Group them mentally by what they *do*, not what they *are* syntactically. A `*_test.go` file and a `charts/*/tests/*.yaml` file are both tests even though one is Go and one is YAML.
- **What does the commit log reveal about groupings?** Commits are the author's own statement of what belonged together. A commit like `chore: bootstrap agent skills` tells you that a batch of structurally diverse files (skill definitions, a lock file, a config doc) were one intentional unit — even if they'd otherwise scatter across several path-based buckets. A commit like `chore: regen CRD manifests` tells you a large YAML change is mechanical, not hand-written. Use this to:
  - **Merge files** that arrived in one commit and share a purpose, even if their paths differ.
  - **Name categories more precisely** — a one-time bootstrap deserves a different label than ongoing maintenance work, and the commit message usually says which it is.
  - **Identify mechanical changes** called out as regeneration or automation in the message; these belong with generated files regardless of where they live.
- **What would a reviewer find surprising about the size?** The point of the table is to explain the number. If the big-ticket items are generated files, plan docs, or tests, that context matters. If everything is production code, the table still confirms that.
- **What groupings are natural for this project?** A Kubernetes operator with a Helm chart has different natural seams than a Node.js API. A repo following a structured planning workflow (e.g. `docs/plans/`) has a category other projects won't. Let the project tell you.

### 3. Form categories by reasoning, not pattern matching

Good categories share a **purpose**, not just a file extension or directory prefix. A few principles:

- **Generated and scaffolded files deserve their own category.** They inflate the numbers but represent no human decision-making. If the project auto-generates CRD manifests, protobuf stubs, deep-copy methods, or OpenAPI clients, those belong together and apart from hand-written code.
- **Tests are almost always their own category.** Across every project type the test-to-production ratio is meaningful signal.
- **Separate workflow artifacts from user-facing docs.** A planning document (`docs/plans/`) written to drive the work is different from a reference page (`docs/site/`) an end user will read. Conflating them hides both signals.
- **Infrastructure boundaries matter.** A Helm chart is not the same as the Go source it packages; a CI workflow is not the same as either. If the project has clear infrastructure layers, model them.
- **Collapse trivia aggressively.** Lock files, version bumps, go.mod, Chart.yaml version lines, README badge updates — absorb these into the nearest logical home (release prep, dependencies, or the category that drove the change). They don't deserve a row.
- **Aim for 4–8 categories.** Fewer loses resolution; more creates noise. Before finalising, scan the bottom of your sorted list: if the last two or three rows together total fewer than ~50 lines, merge them into a single catch-all row (e.g. "Release prep & deps"). A nine-row table where the bottom four rows account for 3% of the diff is worse than a six-row table.

### 4. Assign and sum using awk — never mental arithmetic

Once you know your categories, express them as awk pattern-to-bucket assignments and pipe `--numstat` through the script. The shell counts; you reason. This is the only reliable way to get exact totals across a diff with many files.

Template — replace the `if/else` branches with your actual categories and patterns:

```bash
git diff <base>...HEAD --numstat | awk '
{
  add=$1; del=$2; file=$3

  if      (file ~ /pattern-for-cat-A/)  cat="Category A"
  else if (file ~ /pattern-for-cat-B/)  cat="Category B"
  # ... one branch per category ...
  else                                   cat="Production code"

  sum[cat]["add"] += add
  sum[cat]["del"] += del
  grand_add += add
  grand_del += del
}
END {
  for (c in sum)
    printf "%d\t%d\t%s\n", sum[c]["add"], sum[c]["del"], c
  printf "%d\t%d\tTOTAL\n", grand_add, grand_del
}' | sort -t$'\t' -k1 -rn
```

Every file must land in exactly one bucket — no orphans, no double-counting. After running the script, verify the TOTAL row against the authoritative count:

```bash
git diff <base>...HEAD --shortstat
```

If the numbers don't match, find the gap (a missing pattern or an overlapping condition) and fix the awk before producing the table.

### 5. Produce the table

Use this exact format (fixed-width, code block, additions/removals as signed integers):

```
 Category                          Added Removed
 -------------------------------- ------ -------
 <category name>                   +NNN     -NN
 ...
 ================================ ====== =======
 TOTAL                             +NNN    -NNN
```

- Sort rows by additions descending so the biggest categories read first.
- Pad columns to align. Category column is 32 chars; numeric columns are 6 chars right-aligned.
- Zero removals render as `0`, not `-0`.

### 6. Add a one-sentence interpretation

After the table, one sentence of context if anything stands out — e.g. the test-to-production ratio, a generated-file category that dominates the count, or confirmation that the diff is genuinely as large as it looks. Skip it if nothing is noteworthy.

### 7. Offer PR-ready Markdown

If the context suggests a PR description is being written, also offer this block for copy-paste:

```markdown
**Change Categories**

The line count is large but much of it is <explain dominant non-production categories>:

\`\`\`
 <table>
\`\`\`
```
