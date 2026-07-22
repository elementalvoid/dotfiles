/**
 * Usage quota poller — fetches /api/oauth/usage from Anthropic.
 *
 * This endpoint is undocumented and works only when pi is authenticated via
 * OAuth (Claude Pro/Max subscription, not API key). Returns:
 *
 *   five_hour   – short-term session rate-limit utilisation (0-100 %)
 *   seven_day   – weekly rate-limit utilisation (0-100 %)
 *   extra_usage – spend cap data (used / limit in USD cents)
 *
 * All fields are optional; callers should treat null/undefined as "no data".
 * On any error (auth, network, not-OAuth) we return null and retry on the
 * next poll cycle — the statusline simply omits the segment.
 *
 * Cross-process sharing: successful results (and rate-limit / error state) are
 * persisted to a shared cache file under the agent dir, guarded by a lock
 * directory. Every pi session read-throughs this cache and only hits the
 * network when the cached entry is older than the poll interval AND it wins the
 * lock. This keeps all sessions showing identical numbers and collapses N
 * sessions' request volume down to ~one call per interval — which also keeps us
 * well under the endpoint's aggressive 429 threshold.
 */

import { readFile, writeFile, mkdir, rm, rename, stat } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";

// ── Data shapes ──────────────────────────────────────────────────────────────

export interface RateLimitWindow {
  /** 0-100 */
  utilization: number;
  /** ISO string */
  resets_at: string;
}

export interface ExtraUsage {
  is_enabled: boolean;
  /** In USD cents; null means unlimited */
  monthly_limit: number | null;
  /** In USD cents */
  used_credits: number;
  /** 0-100 */
  utilization: number;
  /** Currency code, e.g. "USD" — present on enterprise/API accounts. */
  currency?: string;
  disabled_reason?: string | null;
}

export interface UsageQuota {
  five_hour?: RateLimitWindow;
  seven_day?: RateLimitWindow;
  seven_day_sonnet?: RateLimitWindow;
  extra_usage?: ExtraUsage;
}

export interface QuotaUpdate {
  quota: UsageQuota | null;
  /** ms timestamp of the last successful fetch, or null before the first. */
  lastUpdated: number | null;
  /**
   * Short human-readable description of the most recent fetch failure, or
   * null when the last fetch succeeded. Surfaced in the statusline as
   * `(error: ...)` so transient/silent breakage (e.g. the endpoint's
   * undocumented 429 throttling) is visible rather than masked as `--/--`.
   */
  error: string | null;
}

/** Internal: a fetch either yields data, or fails with a reason string. */
type FetchResult =
  | { ok: true; quota: UsageQuota }
  | { ok: false; error: string; retryAt?: number };

type Listener = (update: QuotaUpdate) => void;

// ── Rate-limit state ─────────────────────────────────────────────────────────

/**
 * Absolute timestamp (ms) until which we must not hit the endpoint.
 * Mirrors the shared cache's `rateLimitRetryAt`; kept in-process only as a
 * fast-path hint. The shared cache file is authoritative across sessions.
 */
let rateLimitRetryAt: number | null = null;

/**
 * Parse an HTTP `Retry-After` header into a backoff duration in milliseconds.
 *
 * Accepts:
 *   - A positive integer string of seconds (rejects 0 — the endpoint has been
 *     observed returning `Retry-After: 0` while continuing to 429, per
 *     anthropics/claude-code#30930).
 *   - An HTTP-date string (RFC 7231).
 *
 * Falls back to 5 minutes when the header is absent or unparseable.
 */
export function parseRetryAfter(header: string | null, now: number = Date.now()): number {
  const DEFAULT_MS = 5 * 60_000;
  if (!header) return DEFAULT_MS;
  const v = header.trim();
  const secs = Number(v);
  if (!isNaN(secs) && secs > 0) return secs * 1_000;
  const date = new Date(v).getTime();
  if (!isNaN(date) && date > now) return date - now;
  return DEFAULT_MS;
}

// ── Singleton state ──────────────────────────────────────────────────────────

/** Poll every 5 minutes — usage data changes slowly. */
export const QUOTA_POLL_INTERVAL_MS = 5 * 60_000;

let listeners = new Set<Listener>();
let timer: ReturnType<typeof setInterval> | null = null;
let latest: UsageQuota | null = null;
let latestAt: number | null = null;
let latestError: string | null = null;
let fetching = false;

// ── Shared cross-process cache ───────────────────────────────────────────────

/** On-disk shape shared by every pi session. */
interface CacheFile {
  /** Last successfully-fetched quota, or null. */
  quota: UsageQuota | null;
  /** ms timestamp of the last SUCCESSFUL fetch. */
  lastUpdated: number | null;
  /** ms timestamp of the last network ATTEMPT (success or failure). */
  lastAttempt: number | null;
  /** Reason string from the last failed attempt, or null after a success. */
  error: string | null;
  /** Absolute ms until which no session may hit the endpoint (429 backoff). */
  rateLimitRetryAt: number | null;
}

/** Shared cache lives under ~/.pi/cache, independent of the agent dir. */
function cacheDir(): string {
  return join(homedir(), ".pi", "cache");
}

function cacheJsonPath(): string {
  return join(cacheDir(), "statusline-usage.json");
}

/** Lock is a directory (mkdir is atomic and portable) next to the cache. */
function lockDirPath(): string {
  return join(cacheDir(), "statusline-usage.lock");
}

/** A held lock older than this is presumed abandoned (crashed process). */
const STALE_LOCK_MS = 30_000;

async function readCache(): Promise<CacheFile | null> {
  try {
    const raw = await readFile(cacheJsonPath(), "utf-8");
    return JSON.parse(raw) as CacheFile;
  } catch {
    return null;
  }
}

async function writeCache(c: CacheFile): Promise<void> {
  const path = cacheJsonPath();
  try {
    await mkdir(cacheDir(), { recursive: true });
    // Write-then-rename for atomicity so readers never see a partial file.
    const tmp = `${path}.${process.pid}.tmp`;
    await writeFile(tmp, JSON.stringify(c), "utf-8");
    await rename(tmp, path);
  } catch {
    /* cache is best-effort; a write failure just means less sharing */
  }
}

/** Try to acquire the shared lock, stealing it if it looks abandoned. */
async function acquireLock(): Promise<boolean> {
  const dir = lockDirPath();
  // The lock is a non-recursive mkdir (atomic), so its parent must exist first.
  try {
    await mkdir(cacheDir(), { recursive: true });
  } catch {
    /* parent creation best-effort; the mkdir below will report real failures */
  }
  try {
    await mkdir(dir);
    return true;
  } catch {
    // Already held — check whether it's stale and steal it if so.
    try {
      const st = await stat(dir);
      if (Date.now() - st.mtimeMs > STALE_LOCK_MS) {
        await rm(dir, { recursive: true, force: true });
        await mkdir(dir);
        return true;
      }
    } catch {
      /* lost the race to inspect/steal; treat as not acquired */
    }
    return false;
  }
}

async function releaseLock(): Promise<void> {
  try {
    await rm(lockDirPath(), { recursive: true, force: true });
  } catch {
    /* best-effort */
  }
}

const sleep = (ms: number) => new Promise<void>(r => setTimeout(r, ms));

// ── Auth helpers ─────────────────────────────────────────────────────────────

interface AuthEntry {
  type: string;
  access?: string;
  expires?: number;
}

/**
 * Resolve pi's global auth.json. Honors the same overrides pi does so we don't
 * read a stale/nonexistent file when the agent dir is relocated (env var, or a
 * rebranded/VM install with a different HOME than the one on disk we expect).
 */
function authJsonPath(): string {
  const dir =
    process.env.PI_CODING_AGENT_DIR ||
    process.env.PI_AGENT_DIR ||
    join(homedir(), ".pi", "agent");
  return join(dir, "auth.json");
}

/**
 * Read the OAuth access token, returning either the token or a specific reason
 * it's unavailable. The reason is surfaced in the statusline so a null token
 * no longer collapses into an opaque "not authed" — we can tell a missing file
 * apart from an API-key entry, an expired token, or a mid-rewrite parse error.
 */
async function readAccessToken(): Promise<{ token: string } | { error: string }> {
  const authPath = authJsonPath();
  let raw: string;
  try {
    raw = await readFile(authPath, "utf-8");
  } catch {
    return { error: "auth.json not found" };
  }
  let auth: Record<string, AuthEntry>;
  try {
    auth = JSON.parse(raw) as Record<string, AuthEntry>;
  } catch {
    // Almost always a non-atomic rewrite by pi's token refresh — transient.
    return { error: "auth.json unreadable (refreshing?)" };
  }
  const entry = auth["anthropic"];
  if (!entry) return { error: "no anthropic credential" };
  if (entry.type !== "oauth") return { error: "anthropic auth is not OAuth" };
  if (!entry.access) return { error: "no access token" };
  // If expired, pi refreshes lazily on its next API call — transient for us.
  if (typeof entry.expires === "number" && entry.expires < Date.now()) {
    return { error: "token expired (awaiting refresh)" };
  }
  return { token: entry.access };
}

// ── Fetch ────────────────────────────────────────────────────────────────────

async function fetchUsageQuota(): Promise<FetchResult> {
  const auth = await readAccessToken();
  if ("error" in auth) return { ok: false, error: auth.error };
  const token = auth.token;

  try {
    const res = await fetch("https://api.anthropic.com/api/oauth/usage", {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
        // The usage endpoint requires the OAuth beta header (otherwise 401),
        // and routes unrecognized User-Agents into an aggressively
        // rate-limited bucket that returns persistent 429s. Identifying as a
        // claude-code client lands us in the generous bucket.
        // See anthropics/claude-code#30930, #31637.
        "anthropic-beta": "oauth-2025-04-20",
        "User-Agent": "claude-cli/1.0 (external, pi-statusline)",
      },
    });

    if (res.status === 429) {
      const delay = parseRetryAfter(res.headers.get("Retry-After"));
      return {
        ok: false,
        error: `rate limited, retry in ${fmtDelay(delay)}`,
        retryAt: Date.now() + delay,
      };
    }
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}` };
    const data = (await res.json()) as UsageQuota & { error?: unknown };
    if (data.error) return { ok: false, error: "endpoint error" };
    return { ok: true, quota: data };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, error: `network: ${msg}` };
  }
}

/** Compact a backoff duration (ms) into "45s" / "12m" / "2h" for display. */
function fmtDelay(ms: number): string {
  if (ms < 60_000) return `${Math.round(ms / 1_000)}s`;
  if (ms < 3_600_000) return `${Math.round(ms / 60_000)}m`;
  return `${Math.round(ms / 3_600_000)}h`;
}

// ── Poller ───────────────────────────────────────────────────────────────────

/** Adopt a cache snapshot into module memory and notify listeners. */
function emitFromCache(c: CacheFile | null): void {
  const now = Date.now();
  if (c) {
    latest = c.quota;
    latestAt = c.lastUpdated;
    // A live rate-limit window takes precedence and shows a fresh countdown.
    if (c.rateLimitRetryAt !== null && now < c.rateLimitRetryAt) {
      latestError = `rate limited, retry in ${fmtDelay(c.rateLimitRetryAt - now)}`;
    } else {
      latestError = c.error;
    }
    rateLimitRetryAt = c.rateLimitRetryAt;
  }
  const update: QuotaUpdate = { quota: latest, lastUpdated: latestAt, error: latestError };
  for (const l of [...listeners]) {
    try { l(update); } catch { /* never let a listener tear down the poller */ }
  }
}

/** True when the cache is recent enough that no session should re-fetch. */
function cacheIsFresh(c: CacheFile | null, now: number): boolean {
  if (!c) return false;
  if (c.rateLimitRetryAt !== null && now < c.rateLimitRetryAt) return true;
  return c.lastAttempt !== null && now - c.lastAttempt < QUOTA_POLL_INTERVAL_MS;
}

async function refresh(): Promise<void> {
  if (fetching) return;
  fetching = true;
  try {
    const now = Date.now();
    let cache = await readCache();

    // Fast path: a recent shared result (or active 429 window) — no network.
    if (cacheIsFresh(cache, now)) {
      emitFromCache(cache);
      return;
    }

    // Stale: exactly one session should fetch. Try to win the lock.
    if (!(await acquireLock())) {
      // Another session is fetching. Give it a moment, then re-read its result.
      await sleep(1_500);
      cache = await readCache();
      emitFromCache(cache);
      return;
    }

    try {
      // Re-check under the lock: the previous holder may have just written.
      const fresh = await readCache();
      if (cacheIsFresh(fresh, Date.now())) {
        emitFromCache(fresh);
        return;
      }

      const result = await fetchUsageQuota();
      const prev = fresh ?? cache;
      const next: CacheFile = {
        quota: result.ok ? result.quota : (prev?.quota ?? null),
        lastUpdated: result.ok ? Date.now() : (prev?.lastUpdated ?? null),
        lastAttempt: Date.now(),
        error: result.ok ? null : result.error,
        rateLimitRetryAt: result.ok
          ? null
          : (result.retryAt ?? prev?.rateLimitRetryAt ?? null),
      };
      await writeCache(next);
      emitFromCache(next);
    } finally {
      await releaseLock();
    }
  } finally {
    fetching = false;
  }
}

export function subscribeUsageQuota(listener: Listener): () => void {
  listeners.add(listener);

  // Emit the currently cached value immediately (may be null on first call).
  queueMicrotask(() => {
    if (listeners.has(listener)) listener({ quota: latest, lastUpdated: latestAt, error: latestError });
  });

  if (listeners.size === 1) {
    void refresh();
    timer = setInterval(() => void refresh(), QUOTA_POLL_INTERVAL_MS);
    timer.unref?.();
  }

  return () => {
    if (!listeners.delete(listener)) return;
    if (listeners.size === 0 && timer !== null) {
      clearInterval(timer);
      timer = null;
    }
  };
}

/** For tests only — resets module state. */
export function __resetQuotaPollerForTests(): void {
  if (timer !== null) clearInterval(timer);
  timer = null;
  listeners = new Set();
  latest = null;
  latestAt = null;
  latestError = null;
  fetching = false;
  rateLimitRetryAt = null;
}

// ── Formatting helpers (pure, exported for tests)

/**
 * Human-readable age of the last successful usage fetch.
 * Under 1 min → "just now", under 1 h → "Xm", otherwise → "Xh".
 */
export function fmtQuotaAge(lastUpdated: number, now: number = Date.now()): string {
  const elapsed = now - lastUpdated;
  if (elapsed < 60_000) return "just now";
  if (elapsed < 3_600_000) return `${Math.floor(elapsed / 60_000)}m`;
  return `${Math.floor(elapsed / 3_600_000)}h`;
}

// ── formatUsageQuota ─────────────────────────────

/**
 * Format a UsageQuota into a short human-readable string to append to the
 * status line, or return null if there's nothing worth showing.
 *
 * Priority:
 *   1. Extra usage with a limit  →  `$xx.xx/$yy.yy`
 *   2. Extra usage, unlimited    →  `$xx.xx`
 *   3. Five-hour utilisation     →  `N% (5h)`
 *   4. Seven-day utilisation     →  `N% (7d)`
 */
export function formatUsageQuota(quota: UsageQuota | null): string | null {
  if (!quota) return null;

  const eu = quota.extra_usage;
  if (eu?.is_enabled) {
    const used = (eu.used_credits / 100).toFixed(2);
    if (eu.monthly_limit !== null && eu.monthly_limit !== undefined && eu.monthly_limit > 0) {
      const limit = (eu.monthly_limit / 100).toFixed(2);
      return `$${used}/$${limit}`;
    }
    // Enabled but no spending cap — show spend without denominator.
    return `$${used}`;
  }

  // Fall back to rate-limit window utilisation.
  const fh = quota.five_hour;
  if (fh && fh.utilization > 0) {
    return `${Math.round(fh.utilization)}% (5h)`;
  }
  const sd = quota.seven_day;
  if (sd && sd.utilization > 0) {
    return `${Math.round(sd.utilization)}% (7d)`;
  }

  return null;
}
