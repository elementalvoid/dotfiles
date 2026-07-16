# Deep Security Review & Risk Rubric

This is the inspection contract for every candidate update. The goal is not to
read every line — it is to catch the classes of change that turn a routine
version bump into a supply-chain compromise. Extensions run with full system
permissions, so treat each update as installing new code from a third party.

## How installs run here (context for weighting findings)

pi does **not** pass `--ignore-scripts`; it relies on the configured package
manager's default (see the inventory's `packageManager` field). On **bun**
(current setup) dependency lifecycle scripts are **blocked by default** (opt-in
`trustedDependencies` + bun's built-in auto-trust allowlist), so a dependency
`postinstall` is normally inert. On **npm** everything runs. Two caveats hold
regardless of manager: a **git extension's own root scripts run** (pi installs
inside the clone dir, so the extension is the root project, not a dependency),
and the manager can change. Rate install-script findings against the active
`packageManager`, and always state which manager the finding assumes.

## Golden rules

- **Never execute the code you are evaluating.** Do all fetch/extract in a
  throwaway temp dir using plain `curl`/`tar`/`git` (no package manager, so no
  scripts). Do not run the extension, its build, or its lifecycle scripts
  during review.
- **Prefer manager-agnostic tooling.** Use the npm registry HTTP API for
  metadata/tarballs so review works regardless of the active manager (and even
  if node is uninstalled); reserve the reported `packageManager` for `audit`
  and real installs.
- **Inspect the artifact that will actually run.** For npm that is the
  published tarball, not just the git tag. For git it is the exact commit.
- **Diff the metadata before the logic.** `package.json`, dependencies, scripts,
  bin, and ownership carry more risk signal per line than app code.

## What to gather per candidate

### npm

Primary source is the registry JSON at `https://registry.npmjs.org/<name>`
(manager-agnostic; `bun info <name> --json` is an equivalent convenience).

1. Versions & channel: `versions` (all published), `dist-tags` (what `latest`
   points to), `time` (publish dates — a `latest` only hours old deserves more
   scrutiny). All present in the registry JSON.
2. Ownership & provenance:
   - `maintainers` in the registry JSON — compare against the currently
     installed version's maintainers. **A change of maintainers/owners is a
     high-risk signal**, especially paired with a sudden version jump.
   - `dist.integrity` and `dist.signatures` / `dist.attestations` per version —
     registry signature / provenance status. (`bun audit` reports vulns but not
     signatures; use the registry fields for provenance.)
3. Advisories: `<packageManager> audit` (`bun audit` / `bun pm scan`) against
   the candidate; also check GitHub Security Advisories for the package.
4. Deprecation: the `deprecated` field on the version object in the registry
   JSON.
5. The tarball itself (no manager, no scripts):

   ```text
   cd "$(mktemp -d)"
   curl -sL "$(node -e '...dist.tarball...')" -o pkg.tgz   # url from registry JSON
   tar -xzf pkg.tgz         # extracts to package/
   ```

   Diff `package/package.json` and source against the currently installed
   version (installed copy lives under the manager's node_modules dir in the
   inventory).
6. Follow to git (required by the workflow): read the `repositoryUrl` from the
   inventory, then compare the tag/ref for the current vs candidate version.
   **Flag any divergence between the npm tarball contents and the git tag** —
   published code that does not match its open-source repo is a red flag.

### git

1. `git ls-remote <repoUrl>` — enumerate branches/tags and their SHAs; identify
   the default branch head.
2. Fetch into a temp clone, then confirm the **candidate SHA is reachable**:
   `git merge-base --is-ancestor <candidateSha> <defaultBranchSha>` (or that it
   is an exact tag/branch tip). An unreachable/orphan SHA (possible force-push)
   is disqualifying until explained.
3. `git log --oneline <currentSha>..<candidateSha>` and
   `git diff <currentSha> <candidateSha>` for the full change set.

## The diff checklist (what to actually look for)

Scan the diff for these categories and note every hit with file + line:

- **Lifecycle scripts**: added/changed `preinstall`, `install`, `postinstall`,
  `prepare` in `package.json`. Risk is manager-dependent: high under npm (runs
  on install); under bun/pnpm a *dependency's* scripts are blocked unless
  trusted, but a **git extension's own** scripts still run. Report the script
  contents and state whether it would execute given the active `packageManager`.
- **New dependencies / transitive fan-out**: new entries in `dependencies`,
  version widening, or a dependency swapped to a fork/git URL. Each new dep is
  new third-party code.
- **`bin` changes**: new executables shimmed onto PATH.
- **Process & shell**: `child_process`, `exec`, `spawn`, `execSync`, backticks
  shelling out, `eval`, `new Function`, `vm`.
- **Network egress**: `fetch`, `http(s).request`, `net`, `dgram`, websockets,
  new hard-coded hosts/IPs/URLs. Note especially exfil-shaped calls (POST of
  env/fs contents).
- **Credential & environment access**: reads of `process.env`, `~/.ssh`,
  `~/.aws`, `~/.pi/agent/auth.json`, `.npmrc`, keychains, browser profiles,
  `.git-credentials`, cloud metadata endpoints (169.254.169.254).
- **Filesystem writes outside the workspace**: writes to home dir, shell rc
  files, cron, LaunchAgents, `.pi` config, or anything global.
- **pi-specific abuse surface**: new tools/commands that auto-run bash, changes
  to `tool_call`/`user_bash`/`before_provider_request` hooks that could
  intercept commands or leak provider payloads/headers.
- **Obfuscation**: minified/packed blobs in source, base64/hex blobs,
  `String.fromCharCode` chains, dynamic requires of computed names. Obfuscation
  in a source diff is itself a finding.
- **Churn size**: record files changed / lines added-removed as a proxy for how
  much trust the bump requires. A "patch" with a huge diff is suspicious.

## Risk rating

Assign one rating per candidate with a one-line rationale tied to findings.

| Rating | Meaning | Typical triggers |
|--------|---------|------------------|
| **low** | Mechanical, reviewable, no sensitive surface | small diff, no new deps/scripts, no network/cred/process access, maintainers unchanged, tarball matches git |
| **medium** | Benign-looking but touches sensitive surface or is hard to fully verify | new deps, notable network/fs code, large diff, major version bump with API changes |
| **high** | Multiple risk signals or a single serious one | added install scripts that will execute under the active manager, new credential/exfil-shaped access, maintainer change + version jump, tarball diverges from git |
| **critical** | Active red flags; do not recommend | obfuscated payloads, unreachable/force-pushed SHA, known advisory with exploit, secret exfiltration |

Recommendation policy:

- Recommend **only** the safest reachable target, not reflexively `latest`.
  A patch/minor with a clean diff beats a major with churn.
- For **medium+**, default recommendation is *hold* or *update to an earlier
  safe version*, and say exactly what a human should eyeball before approving.
- Present **majors** separately from patch/minor even when they look clean, so
  breaking-change risk is a conscious choice.
