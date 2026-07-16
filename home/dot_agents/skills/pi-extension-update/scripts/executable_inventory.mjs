#!/usr/bin/env node
// Build a deterministic inventory of installed pi packages (extensions) from
// user + project settings.json, resolving each to its current pin and the
// version/commit actually on disk. Read-only. Emits JSON to stdout.
//
// Usage: node inventory.mjs [--project-dir <dir>]
//   --project-dir defaults to process.cwd() (used to find .pi/settings.json)
//
// Notes:
//   - Never runs npm/git. It only reads local files so it is safe and fast.
//     The online checks (registry, ls-remote, diffs) are driven by the skill
//     workflow using the npmCommand reported here.
//   - Only npm: and git: sources are reported as updatable. Local paths are
//     listed with type "local" and skipped for update purposes.

import { readFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { homedir } from "node:os";

const args = process.argv.slice(2);
let projectDir = process.cwd();
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--project-dir") projectDir = resolve(args[++i]);
}

// pi's config dir is rebrandable; honor override, else default to ~/.pi/agent.
const userConfigDir =
  process.env.PI_CONFIG_DIR || join(homedir(), ".pi", "agent");
const projectConfigDir = join(projectDir, ".pi");

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

// Parse an npm source spec into { name, version } handling scoped names.
// "npm:@scope/pkg@1.2.3" -> { name: "@scope/pkg", version: "1.2.3" }
// "npm:pkg"              -> { name: "pkg", version: null }
function parseNpm(spec) {
  const body = spec.slice("npm:".length);
  const at = body.lastIndexOf("@");
  if (at > 0) {
    return { name: body.slice(0, at), version: body.slice(at + 1) };
  }
  return { name: body, version: null };
}

// Parse a git source spec into { repoUrl, ref, host, path }.
// The pinned ref is the trailing @segment IFF it has no "/" or ":" (so we do
// not mistake the "@" in git@github.com or a URL path for a ref).
function parseGit(spec) {
  let body = spec.startsWith("git:") ? spec.slice("git:".length) : spec;
  let ref = null;
  const parts = body.split("@");
  const last = parts[parts.length - 1];
  if (parts.length > 1 && !last.includes("/") && !last.includes(":")) {
    ref = last;
    body = parts.slice(0, -1).join("@");
  }
  // Normalize to host + path for clone-dir mapping.
  let hostPath = body
    .replace(/^https?:\/\//, "")
    .replace(/^ssh:\/\//, "")
    .replace(/^git:\/\//, "")
    .replace(/^git@/, "")
    .replace(/^[^@]*@/, "") // strip any leading user@
    .replace(":", "/"); // git@github.com:user/repo -> github.com/user/repo
  const segs = hostPath.split("/").filter(Boolean);
  const host = segs[0] || null;
  const path = segs.slice(1).join("/").replace(/\.git$/, "");
  return { repoUrl: body, ref, host, path };
}

function gitHeadSha(cloneDir) {
  try {
    const head = readFileSync(join(cloneDir, ".git", "HEAD"), "utf8").trim();
    if (head.startsWith("ref:")) {
      const refPath = head.slice(4).trim();
      const p = join(cloneDir, ".git", refPath);
      if (existsSync(p)) return readFileSync(p, "utf8").trim();
      // packed-refs fallback
      const packed = readFileSync(join(cloneDir, ".git", "packed-refs"), "utf8");
      for (const line of packed.split("\n")) {
        const [sha, name] = line.split(" ");
        if (name === refPath) return sha;
      }
      return null;
    }
    return head; // detached: HEAD holds the sha directly
  } catch {
    return null;
  }
}

function inspectEntry(entry, scope, configDir) {
  const source = typeof entry === "string" ? entry : entry.source;
  const filters =
    typeof entry === "object"
      ? Object.fromEntries(
          Object.entries(entry).filter(([k]) => k !== "source"),
        )
      : {};
  const base = { scope, source, filters };

  if (source.startsWith("npm:")) {
    const { name, version } = parseNpm(source);
    const pkgDir = join(configDir, "npm", "node_modules", name);
    const pkg = readJson(join(pkgDir, "package.json"));
    let repositoryUrl = null;
    if (pkg?.repository) {
      repositoryUrl =
        typeof pkg.repository === "string"
          ? pkg.repository
          : pkg.repository.url || null;
    }
    return {
      ...base,
      type: "npm",
      name,
      pinnedVersion: version, // null = unpinned (drifts on pi update)
      installedVersion: pkg?.version || null,
      repositoryUrl,
      installedDeps: pkg?.dependencies || {},
      hasInstallScripts: !!(
        pkg?.scripts &&
        (pkg.scripts.preinstall || pkg.scripts.install || pkg.scripts.postinstall)
      ),
    };
  }

  if (
    source.startsWith("git:") ||
    source.startsWith("https://") ||
    source.startsWith("http://") ||
    source.startsWith("ssh://")
  ) {
    const { repoUrl, ref, host, path } = parseGit(source);
    const cloneDir =
      host && path ? join(configDir, "git", host, path) : null;
    return {
      ...base,
      type: "git",
      repoUrl,
      host,
      path,
      pinnedRef: ref, // should be a 40-char sha; null/tag = policy violation
      pinnedIsSha: !!(ref && /^[0-9a-f]{40}$/i.test(ref)),
      cloneDir,
      installedSha: cloneDir ? gitHeadSha(cloneDir) : null,
    };
  }

  return { ...base, type: "local" };
}

// Mirror pi's getPackageManagerName(): the token after the last "--" separator,
// else the first command element; basename with .cmd/.exe stripped.
function packageManagerName(npmCommand) {
  const sep = npmCommand.lastIndexOf("--");
  const cmd = sep >= 0 ? npmCommand[sep + 1] : npmCommand[0];
  if (!cmd) return "npm";
  return cmd.split(/[\\/]/).pop().replace(/\.(cmd|exe)$/i, "");
}

function collect(configDir, scope) {
  const settings = readJson(join(configDir, "settings.json"));
  const packages = settings?.packages || [];
  const npmCommand = settings?.npmCommand || ["npm"];
  return {
    npmCommand,
    settingsPath: join(configDir, "settings.json"),
    entries: packages.map((e) => inspectEntry(e, scope, configDir)),
  };
}

const user = collect(userConfigDir, "user");
const project = existsSync(join(projectConfigDir, "settings.json"))
  ? collect(projectConfigDir, "project")
  : { npmCommand: user.npmCommand, settingsPath: null, entries: [] };

const out = {
  generatedAt: new Date().toISOString(),
  userConfigDir,
  projectConfigDir,
  npmCommand: user.npmCommand,
  packageManager: packageManagerName(user.npmCommand),
  user: { settingsPath: user.settingsPath, entries: user.entries },
  project: { settingsPath: project.settingsPath, entries: project.entries },
};

process.stdout.write(JSON.stringify(out, null, 2) + "\n");
