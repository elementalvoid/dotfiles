---
name: pi-extension-update
description: Safely check for, security-review, and apply updates to installed pi extensions/packages (npm and git sources) declared in settings.json. Use whenever the user wants to update, upgrade, bump, audit, or check for new versions of their pi extensions, plugins, or packages, or asks "are my extensions out of date?" / "can I safely update <package>?" — even if they don't name a specific package. Deeply inspects code changes between current and candidate versions, follows npm packages to their git source, rates each update's safety, and only edits settings after explicit approval.
metadata:
  version: "1.0.0"
  tags: pi,extensions,packages,updates,security,supply-chain,npm,git
---

# Pi Extension Update

Check installed pi extensions for updates, **deeply** inspect the code changes
between the installed and available versions, rate each update's safety, and —
only after explicit approval — pin the new versions in `settings.json`.

Extensions run with full system permissions, so every update is effectively
"install new third-party code." Treat this as a security review, not a chore.

## Hard rules (non-negotiable)

1. **No writes without explicit approval.** Never edit `settings.json`,
   never run `pi install`/`pi update`, until the user approves a specific set
   of changes. Discovery and inspection are read-only.
2. **Git sources pin a full 40-char commit SHA — never a tag or branch.**
   Git tags and branches are mutable (a maintainer can re-point them at
   different content), so a tag is not a safe pin. Resolve the intended
   release to its commit SHA and pin that.
3. **npm sources pin an exact version — never a range or `latest`.**
   No `^`, `~`, `*`, or dist-tags. Pinned specs are also what freezes them
   against `pi update` drift.
4. **Never execute the code under review.** All fetch/pack/clone steps use
   `--ignore-scripts` in a temp dir. See `references/security-review.md`.
5. **Recommend the safest reachable target, not reflexively `latest`.**

## Runtime & package manager (this machine)

pi is a standalone **bun** binary — bun is the runtime, and extensions load via
jiti on that embedded bun. Package installs go through the `npmCommand` in
settings, currently **mise-pinned `bun`** (the inventory reports the resolved
`packageManager`). Two consequences that shape the risk assessment:

- **pi does not pass `--ignore-scripts`; it relies on the package manager's
  default.** So the manager *is* the control over lifecycle scripts.
- **bun blocks dependency lifecycle scripts by default** (opt-in via
  `trustedDependencies`, plus bun's built-in auto-trust allowlist of popular
  packages). So a dependency's `postinstall` is normally inert here — unlike
  npm, which runs everything. Weight install-script findings accordingly, but
  note two gaps: (a) a **git extension's own root scripts run regardless of
  manager**, because pi runs the install *inside* the clone dir (the extension
  is the root project, not a dependency); (b) if `packageManager` is ever `npm`,
  all scripts run. Always read `packageManager` from the inventory and frame
  script risk against it — do not assume npm.

Prefer **manager-agnostic** read-only tooling for inspection so this works
regardless of the active manager (and even if node is uninstalled): the npm
registry HTTP API for metadata/tarballs, plain `git`/`tar`/`curl` for fetch and
extract, and the reported `packageManager` only for `audit` and any real
install. Bun equivalents where a manager call is wanted: `bun info <pkg>` for
metadata, `bun audit` / `bun pm scan` for vulnerabilities.

## Why editing settings is the mechanism

Once a spec is pinned (npm `@x.y.z`, git `@<sha>`), `pi update --extensions`
and `pi update --all` deliberately **skip** it — they will not move a pinned
package to a newer version. So "updating" a pinned extension means changing the
pin in `settings.json`, then letting pi reconcile the install. That is exactly
what this skill does, with a review gate in front of the write.

## Workflow

### 1. Inventory (read-only)

Run the scanner to get a reliable picture of what is declared and what is on
disk, across both user (`~/.pi/agent/settings.json`) and project
(`.pi/settings.json`) settings:

```text
node <skill-dir>/scripts/inventory.mjs --project-dir "$PWD"
```

It reports, per entry: scope, source spec, type (npm/git/local), current pin,
the version/SHA actually installed, object-form filters to preserve, the npm
`repositoryUrl` (for the npm→git follow), and the `npmCommand` wrapper to use.

Flag immediately, before any update check:

- **Unpinned entries** (`pinnedVersion: null` / `pinnedRef: null`) — these drift
  on every `pi update`. Offer to pin them to what is currently installed.
- **Git pins that are not a 40-char SHA** (`pinnedIsSha: false`) — a tag/branch
  pin violates rule 2. Offer to convert to the equivalent SHA.

Use the reported `npmCommand` array for **all** npm calls (the user may route
npm through `mise`/`asdf`). Skip `type: "local"` entries — they are not
updatable from a registry/remote.

### 2. Check for available updates

- **npm packages** (manager-agnostic): fetch
  `https://registry.npmjs.org/<name>` and read `versions`, `dist-tags`, and
  `time`. (Equivalently `bun info <name> --json`.) Identify candidate targets
  newer than `installedVersion`, noting latest patch, latest minor, and latest
  major separately.
- **git**: `git ls-remote <repoUrl>` to list tags/branches and the default
  branch head. Candidates are newer tagged releases and/or the default branch
  head, each resolved to its SHA.

If nothing is newer, say so per package and stop there.

### 3. Deep inspection (the core of this skill)

For every candidate, follow `references/security-review.md` in full. In short:

- **npm → git follow (required):** read `repositoryUrl` from the inventory and
  diff the current release tag/ref against the candidate. Also inspect the
  actual published **tarball** — fetch the version's `dist.tarball` URL from the
  registry JSON with `curl` and `tar -xzf` in a temp dir (no manager, no
  scripts) — and **flag any divergence between the tarball and the git tag**.
- **git:** confirm the candidate SHA is reachable (an ancestor of the default
  branch head or an exact tag/branch tip — not an orphan/force-pushed commit),
  then read `git log`/`git diff` from current to candidate SHA.
- Prioritize metadata over logic: dependency changes, added `preinstall`/
  `install`/`postinstall` scripts, `bin` changes, and **maintainer/ownership
  changes**. Then scan the diff for process/shell exec, network egress,
  credential/env access, out-of-workspace writes, pi-hook abuse, and
  obfuscation. Run `<packageManager> audit` (`bun audit` / `bun pm scan` here)
  and check advisories/deprecation. Frame install-script findings against the
  active `packageManager` per the runtime note above.

Do the heavy fetching/diffing in parallel across packages when possible, but
never skip a candidate the user might approve.

### 4. Propose (no changes yet)

Present one table plus a short rationale per package. Assign each candidate a
risk rating (**low / medium / high / critical**) per the rubric, and recommend
the safest reachable target — which may be an earlier version than `latest`, or
"hold."

```text
Package            Type  Installed → Proposed        Risk    Recommend  Why
-----------------  ----  --------------------------  ------  ---------  --------------------------------
pi-subagents       npm   0.34.0 → 0.35.2             low     update     small diff, no new deps/scripts
@scope/foo         npm   1.2.0 → 2.0.0 (major)       medium  review     API change; new network call L42
pi-hooks           git   5590a3b → 9f1c… (main head) high    hold       new postinstall + maintainer chg
```

Always show git proposals as the resolved **SHA** (with the tag it corresponds
to in parentheses for readability). Separate majors from patch/minor so a
breaking-change bump is a conscious choice. Then ask for approval — per package
or "approve all low-risk," the user's call. Do not proceed on silence.

### 5. Apply (only the approved subset)

1. **Back up** each settings file you will touch:
   `cp settings.json settings.json.bak-$(date +%Y%m%d%H%M%S)`.
2. Edit `packages` in place, changing only the approved entries:
   - **npm**: set the exact version — `"npm:<name>@<version>"`, or update the
     `source` field for object-form entries. **Preserve all filters**
     (`extensions`, `skills`, `prompts`, `themes`) exactly.
   - **git**: set the full SHA — `"git:host/user/repo@<40-char-sha>"`. Preserve
     filters. Confirm again the SHA is a real, reachable commit.
3. **Validate JSON** after every edit (`node -e 'JSON.parse(...)'` or
   `python3 -m json.tool`). If it fails, restore the backup.
4. Record a **rollback line** per change (the previous exact spec) so reverting
   is a single paste, and show it to the user.
5. Reconcile the install so disk matches the new pins. Prefer letting the user
   run it, or run on their behalf only if they approve the command:
   `pi update --extensions` (reconciles pinned git checkouts and reinstalls via
   the configured `packageManager`), or `pi install <exact-spec>` for a single
   package. Note that a git SHA change requires this reconcile step to actually
   check out the new code.

### 6. Report

Summarize what changed, what was held and why, the rollback lines, and any
unpinned/tag-pinned entries the user declined to fix (so they resurface next
run).

## Notes on scope & dedup

A package can appear in both user and project settings; the project entry wins
(unless `autoload: false`, where it layers as a delta). Update each scope's file
independently and tell the user which scope a change lands in. Identity for
matching across scopes: npm = package name; git = repo URL without ref.
