---
name: pi-extension-update
description: >-
  Safely install new pi extensions/packages and security-review updates to
  already-installed ones (npm and git sources) declared in settings.json. Use
  whenever the user wants to install, add, or try a pi extension/plugin/package —
  for example "I want to install this extension" followed by a spec such as
  git:github.com/user/repo, a pasted `pi install npm:foo` or
  `pi install git:github.com/user/repo` command, or a bare repo URL or npm name
  offered as an extension — and whenever they want to update, upgrade, bump,
  audit, or check for new versions, or ask whether their extensions are out of
  date or whether a package is safe to install or update. Deeply inspects the
  code that will actually run (whole package for a first install, diff for an
  update), follows npm packages to their git source, rates safety, pins an exact
  version or commit SHA, and only edits settings or installs after explicit
  approval.
metadata:
  version: "1.1.0"
  tags: pi,extensions,packages,install,updates,security,supply-chain,npm,git
---

# Pi Extension Install & Update

Two modes, one review gate:

- **Mode INSTALL** — the user wants a *new* extension added. Review the whole
  package that would run, then pin an exact version/SHA and install.
- **Mode UPDATE** — the user wants installed extensions moved forward. Review
  the diff between installed and candidate versions, then repin.

Pick the mode from the request: a spec/URL/`pi install …` command to add
something new → INSTALL; "update/upgrade/bump/out of date/audit" → UPDATE. If
the user pastes a spec that the inventory shows is already installed at a
different version, that is UPDATE. If genuinely ambiguous, ask.

Extensions run with full system permissions, so both modes are effectively
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
   In particular, do **not** "just try it" with `pi -e <spec>` or `pi install`
   before the review — both run the code.
5. **Recommend the safest reachable target, not reflexively `latest`.**
6. **Never install from an unresolved spec.** A pasted `pi install
   git:github.com/user/repo` (no ref) or `npm:pkg` (no version) must be
   resolved to a SHA/exact version and reviewed before it is run or written.

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

## Why editing settings is the mechanism (Mode UPDATE)

Once a spec is pinned (npm `@x.y.z`, git `@<sha>`), `pi update --extensions`
and `pi update --all` deliberately **skip** it — they will not move a pinned
package to a newer version. So "updating" a pinned extension means changing the
pin in `settings.json`, then letting pi reconcile the install. That is exactly
what this skill does, with a review gate in front of the write.

## Workflow A — INSTALL a new extension

### A1. Parse & normalize the request (read-only)

Accept any of: `pi install <spec>` pasted verbatim, a bare spec
(`git:github.com/user/repo`, `npm:@scope/pkg@1.2.3`), an `https://`/`ssh://`
repo URL, or a plain npm package name. Normalize to a pi source spec and state
back what you parsed: type (npm/git/local), name/repo, and the requested ref (or
"none given").

Also decide and confirm:

- **Scope**: user settings (`~/.pi/agent/settings.json`, default) or project
  settings (`.pi/settings.json`, `pi install -l`). Project scope means teammates
  get the code too — call that out.
- **Filters**: whether to take the whole package or only some resources
  (`extensions`, `skills`, `prompts`, `themes`) via object form.

Local paths (`./x`, `/abs/x`) skip registry/remote work: review the tree on
disk, note there is no pin to make, and treat it as unversioned.

Run the inventory (step B1 below) as well, to check the package is not already
installed and to get `npmCommand`/`packageManager`. If it is already present,
switch to Mode UPDATE.

### A2. Resolve to a pinnable target

- **git**: `git ls-remote <repoUrl>` → tags, branches, default-branch head.
  Prefer the newest sane **release tag** resolved to its 40-char SHA; fall back
  to the default-branch head SHA if there are no tags (say so — an untagged head
  is a moving target that you are freezing). If the user supplied a ref, resolve
  exactly that ref and report which SHA it maps to.
- **npm**: fetch `https://registry.npmjs.org/<name>` → `dist-tags`, `versions`,
  `time`. Pick an exact version; treat a `latest` published hours ago with extra
  suspicion. If the user supplied a version, use it (and flag if it is
  deprecated or outdated).

Sanity-check the source itself before spending effort: repo exists, is not
archived, has plausible history/authorship, and (for npm) `repositoryUrl`
actually points at that repo. A brand-new, single-commit, zero-star repo
trusted with full system access is itself a finding.

### A3. Deep inspection of the whole package (first install = no baseline)

Follow `references/security-review.md`, but review the **entire** artifact
instead of a diff, since there is no trusted prior version:

- Fetch read-only into a temp dir: `git clone` + `git checkout <sha>` for git,
  or `curl` the version's `dist.tarball` and `tar -xzf` for npm. No package
  manager, no scripts, no build.
- Read `package.json` first: lifecycle scripts (`preinstall`/`install`/
  `postinstall`/`prepare` — for a **git** extension these run as root scripts
  regardless of the package manager), `bin`, dependency list and its fan-out,
  and the `pi` manifest (which extensions/skills/hooks it registers).
- Then read every registered extension entry point and hook in full, plus any
  skill that instructs shell use. Apply the whole diff checklist to the source:
  process/shell exec, network egress, credential/env access, out-of-workspace
  writes, pi-hook abuse (`tool_call`, `user_bash`,
  `before_provider_request`), obfuscation.
- npm only: **diff the tarball against the git tag** and flag divergence.
- Run `<packageManager> audit` (`bun audit` / `bun pm scan`) on the resolved
  dependency set; check advisories and deprecation.

### A4. Propose (no changes yet)

One block per package:

```text
Spec requested   git:github.com/DietrichGebert/ponytail (no ref)
Resolved pin     git:github.com/DietrichGebert/ponytail@<40-char-sha> (v0.3.1)
Scope            user (~/.pi/agent/settings.json)
Registers        1 extension (tool_call hook), 2 skills
Risk             medium
Findings         postinstall runs `node build.js` (root scripts DO run for git
                 extensions); fetches https://api.example.com in hook L88
Recommend        install / hold
```

State plainly what capabilities the user is granting, and ask for approval. Do
not proceed on silence.

### A5. Apply (only if approved)

1. Back up the target settings file:
   `cp settings.json settings.json.bak-$(date +%Y%m%d%H%M%S)`.
2. **git only — clear a wedged clone dir first** (see "Wedged git clone dir"
   below). Skipping this makes the install fail on every retry.
3. Install with the **fully pinned** spec — never the spec as pasted:
   - `pi install git:host/user/repo@<40-char-sha>` (add `-l` for project scope)
   - `pi install npm:<name>@<exact-version>`
   Prefer having the user run it; run it yourself only with explicit approval.
4. Verify the resulting `packages` entry in `settings.json` is pinned (SHA /
   exact version) and that filters are as agreed; fix the entry by hand if pi
   wrote something looser. Validate JSON after any hand edit.
5. Report the **removal line** (`pi remove <spec>`) plus the settings backup path
   as the rollback, and re-run the inventory to confirm what landed on disk.

## Workflow B — UPDATE installed extensions

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
3. **git only:** clear a wedged clone dir (see below) before the reconcile in
   step 5, or the new SHA will never be checked out.
4. **Validate JSON** after every edit (`node -e 'JSON.parse(...)'` or
   `python3 -m json.tool`). If it fails, restore the backup.
5. Record a **rollback line** per change (the previous exact spec) so reverting
   is a single paste, and show it to the user.
6. Reconcile the install so disk matches the new pins. Prefer letting the user
   run it, or run on their behalf only if they approve the command:
   `pi update --extensions` (reconciles pinned git checkouts and reinstalls via
   the configured `packageManager`), or `pi install <exact-spec>` for a single
   package. Note that a git SHA change requires this reconcile step to actually
   check out the new code.

### 6. Report

Summarize what changed, what was held and why, the rollback lines, and any
unpinned/tag-pinned entries the user declined to fix (so they resurface next
run).

## Wedged git clone dir (known pi failure mode)

Symptom, on install **or** `pi update --extensions`, repeating identically on
every retry:

```text
 * branch  <sha> -> FETCH_HEAD
Error: git rev-parse HEAD failed with code 128: fatal: ambiguous argument 'HEAD'
```

Cause (pi 0.82.0 `installGit`): if the clone dir already exists, pi takes an
update-only path (`fetch` + `rev-parse HEAD` + `reset --hard`) and **never**
runs `git clone`/`git checkout`. An earlier interrupted clone — an aborted
`pi install`, or a `pi -e <spec>` that was cancelled — leaves a repo with
`origin` set, no checkout, and `.git/HEAD` = `ref: refs/heads/.invalid` (git's
placeholder during a clone). `rev-parse HEAD` then fails forever. The fetch
line in the output makes it look like progress; it is not.

**Preflight before any git install/reconcile.** Take `cloneDir` from the
inventory (never hand-build the path), and only remove a dir that is both under
the pi git root and has no resolvable HEAD:

```bash
D="<cloneDir from inventory>"
case "$D" in */.pi/agent/git/*) ;; *) echo "refusing: $D"; exit 1;; esac
if [ -d "$D" ] && ! git -C "$D" rev-parse HEAD >/dev/null 2>&1; then
  rm -rf "$D"   # half-cloned; pi will do a clean clone + checkout
fi
```

The dir holds no unique state (it is a checkout of a public remote), so
deleting it is safe and non-destructive — but it *is* a write, so mention it in
the approval block rather than doing it silently. If HEAD resolves but points at
the wrong commit, leave it alone: that is the normal path pi's `reset --hard`
handles.

Recovery if the failure already happened (dir exists, install aborted):
`git -C "$D" checkout <sha>` to unwedge in place, or `rm -rf "$D"`, then re-run
the same pinned `pi install`. Afterwards confirm `installedSha` == the pin via
the inventory — a "success" line alone does not prove the checkout moved.

## Notes on scope & dedup

For a fresh install, `pi install` defaults to **user** scope; `-l` targets the
project. Choose deliberately — project scope ships the dependency to everyone
who trusts the repo.

A package can appear in both user and project settings; the project entry wins
(unless `autoload: false`, where it layers as a delta). Update each scope's file
independently and tell the user which scope a change lands in. Identity for
matching across scopes: npm = package name; git = repo URL without ref.
