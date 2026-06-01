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
 * Same singleton/refcounting pattern as poller.ts so multiple sessions share
 * one interval.
 */

import { readFile } from "node:fs/promises";
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
}

type Listener = (update: QuotaUpdate) => void;

// ── Rate-limit state ─────────────────────────────────────────────────────────

/**
 * Absolute timestamp (ms) until which we must not hit the endpoint.
 * Set when the API responds with HTTP 429.
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
let fetching = false;

// ── Auth helpers ─────────────────────────────────────────────────────────────

interface AuthEntry {
  type: string;
  access?: string;
  expires?: number;
}

async function readAccessToken(): Promise<string | null> {
  try {
    const authPath = join(homedir(), ".pi", "agent", "auth.json");
    const raw = await readFile(authPath, "utf-8");
    const auth = JSON.parse(raw) as Record<string, AuthEntry>;
    const entry = auth["anthropic"];
    if (!entry || entry.type !== "oauth") return null;
    if (!entry.access) return null;
    // If the token is expired, skip — pi will refresh it on the next API call.
    if (typeof entry.expires === "number" && entry.expires < Date.now()) return null;
    return entry.access;
  } catch {
    return null;
  }
}

// ── Fetch ────────────────────────────────────────────────────────────────────

async function fetchUsageQuota(): Promise<UsageQuota | null> {
  const token = await readAccessToken();
  if (!token) return null;

  try {
    const res = await fetch("https://api.anthropic.com/api/oauth/usage", {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
        "User-Agent": "pi-statusline-extension",
      },
    });

    if (res.status === 429) {
      const delay = parseRetryAfter(res.headers.get("Retry-After"));
      rateLimitRetryAt = Date.now() + delay;
      return null;
    }
    if (!res.ok) return null;
    const data = (await res.json()) as UsageQuota & { error?: unknown };
    if (data.error) return null;
    return data;
  } catch {
    return null;
  }
}

// ── Poller ───────────────────────────────────────────────────────────────────

async function refresh(): Promise<void> {
  if (fetching) return;
  // Skip the network call while a rate-limit window is active; notify
  // listeners with the stale cached value so the statusline stays visible.
  if (rateLimitRetryAt !== null && Date.now() < rateLimitRetryAt) {
    const staleUpdate: QuotaUpdate = { quota: latest, lastUpdated: latestAt };
    for (const l of [...listeners]) {
      try { l(staleUpdate); } catch { /* never let a listener tear down the poller */ }
    }
    return;
  }
  fetching = true;
  try {
    const result = await fetchUsageQuota();
    // Only update `latest` / `latestAt` on a real response (null = no-auth or 429).
    if (result !== null) {
      latest = result;
      latestAt = Date.now();
    }
    const update: QuotaUpdate = { quota: latest, lastUpdated: latestAt };
    for (const l of [...listeners]) {
      try {
        l(update);
      } catch {
        /* never let a listener tear down the poller */
      }
    }
  } finally {
    fetching = false;
  }
}

export function subscribeUsageQuota(listener: Listener): () => void {
  listeners.add(listener);

  // Emit the currently cached value immediately (may be null on first call).
  queueMicrotask(() => {
    if (listeners.has(listener)) listener({ quota: latest, lastUpdated: latestAt });
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
