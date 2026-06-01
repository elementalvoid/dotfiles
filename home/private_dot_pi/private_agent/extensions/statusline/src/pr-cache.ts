/**
 * Per-branch GitHub PR lookup with caching + in-flight dedupe.
 *
 * Uses `gh pr view --head <branch>` so results are scoped to the branch we
 * actually care about rather than whatever the working-directory HEAD points
 * at. Runs the command with the session's cwd so it resolves the right repo
 * when pi is launched from elsewhere.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export interface PrInfo {
  number: number;
  url: string;
}

type ExecFn = ExtensionAPI["exec"];

export class PrCache {
  private readonly cache = new Map<string, PrInfo | null>();
  private readonly inFlight = new Set<string>();
  private readonly exec: ExecFn;

  constructor(exec: ExecFn) {
    this.exec = exec;
  }

  get(branch: string): PrInfo | null | undefined {
    return this.cache.get(branch);
  }

  /** Kick off a lookup if one isn't already known/in flight. Idempotent. */
  async fetch(branch: string, cwd: string, onDone: () => void): Promise<void> {
    if (this.cache.has(branch) || this.inFlight.has(branch)) return;
    this.inFlight.add(branch);
    try {
      // --repo is inferred from cwd by gh; branch is a positional arg.
      const result = await this.exec(
        "gh",
        ["pr", "view", branch, "--json", "number,url"],
        { timeout: 8000, cwd },
      );
      if (result.code === 0) {
        const stdout = result.stdout.trim();
        try {
          const parsed = JSON.parse(stdout) as PrInfo;
          if (typeof parsed.number === "number" && typeof parsed.url === "string") {
            this.cache.set(branch, parsed);
          } else {
            this.cache.set(branch, null);
          }
        } catch {
          this.cache.set(branch, null);
        }
      } else {
        // Non-zero usually means "no PR for this branch" — treat as negative cache.
        this.cache.set(branch, null);
      }
    } catch {
      this.cache.set(branch, null);
    } finally {
      this.inFlight.delete(branch);
      onDone();
    }
  }
}
