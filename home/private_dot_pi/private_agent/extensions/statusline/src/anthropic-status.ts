/**
 * Anthropic status — fetch, parse, cache, cross-process lock.
 *
 * Design:
 *   - One-shot fetch with AbortController; no dangling timers.
 *   - In-memory promise dedupe so concurrent callers in the same process
 *     share a single network round-trip.
 *   - Cross-process coordination via `O_EXCL` lock file; non-owners read the
 *     cache. Cache is written atomically via `rename()`.
 *   - Parsing is exposed (`selectStatusFromUpdog`) so it can be unit tested
 *     independently of `fetch` and the filesystem.
 */

import { constants } from "node:fs";
import { mkdir, open, readFile, rename, stat, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export type AnthropicStatusLevel = "operational" | "degraded" | "outage" | "unknown";

export interface AnthropicStatus {
  level: AnthropicStatusLevel;
  title?: string;
  incidentUrl?: string;
  /** ms — when the outage/degradation began. */
  outageStart?: number;
  /** ms — when it was resolved (degraded only). */
  outageEnd?: number;
  /** true when cached data is older than STALE_MS. */
  stale?: boolean;
}

export const UPDOG_URL = "https://updog.ai/data/third-party-outages.json";
export const UPDOG_PAGE = "https://updog.ai/status/anthropic";

const CACHE_DIR = join(homedir(), ".pi", "cache");
const CACHE_FILE = join(CACHE_DIR, "updog-anthropic.json");
const CACHE_TMP = `${CACHE_FILE}.tmp`;
const LOCK_FILE = join(CACHE_DIR, "updog-anthropic.lock");

/** Hard ceiling on a single fetch — matches HTTP deadline below. */
const FETCH_TIMEOUT_MS = 10_000;
/** Lock owner self-deadline — fetch timeout + a small write budget. */
const LOCK_OWNER_TTL = 12_000;
/** Last-resort cleanup threshold for a lock left by a SIGKILL'd process. */
const LOCK_MAX_AGE = 15_000;
/** Cache age that triggers the hollow-dot "stale" indicator. */
export const STALE_MS = 7 * 60 * 1000;
/** Refresh cadence. Callers should also poll at this rate. */
export const POLL_INTERVAL_MS = 5 * 60 * 1000;
/** Window during which a recently resolved outage still colors the dot. */
export const RECENT_RESOLVED_MS = 2 * 60 * 60 * 1000;

// ── Raw updog.ai payload shapes ──────────────────────────────────────────────

export interface UpdogIncident {
  id?: string;
  start: number;
  end?: number;
  status?: string;
  title?: string;
  url?: string;
}

export interface UpdogOutage {
  start: number;
  end?: number;
  status?: string;
  linked_status_page_incidents?: UpdogIncident[];
}

export interface UpdogProvider {
  provider_name: string;
  display_name?: string;
  outages?: UpdogOutage[];
}

export interface UpdogPayload {
  data?: { attributes?: { provider_data?: UpdogProvider[] } };
}

// ── Parsing (pure, testable) ─────────────────────────────────────────────────

/**
 * Derive an {@link AnthropicStatus} from the parsed updog payload.
 *
 * Outages are processed in `start`-descending order so the result is
 * deterministic regardless of feed ordering — the most recent active outage
 * wins, and for the "degraded" fallback we pick the most recently resolved
 * outage.
 */
export function selectStatusFromUpdog(payload: UpdogPayload, now: number = Date.now()): AnthropicStatus {
  const providers = payload?.data?.attributes?.provider_data ?? [];
  const anthropic = providers.find(p => p.provider_name === "anthropic");
  if (!anthropic) return { level: "unknown" };

  // Sort a copy so we don't mutate the caller's data.
  const outages = [...(anthropic.outages ?? [])].sort((a, b) => b.start - a.start);

  // Pass 1: find the most recent active outage.
  for (const outage of outages) {
    const isActive = !outage.end || (outage.status !== undefined && outage.status !== "resolved");
    if (!isActive) continue;
    const inc = outage.linked_status_page_incidents?.[0];
    return {
      level: "outage",
      title: inc?.title ?? "Service disruption",
      incidentUrl: inc?.url ?? UPDOG_PAGE,
      outageStart: inc?.start ?? outage.start,
    };
  }

  // Pass 2: most recent resolved-within-window, picked by max(end).
  let best: { outage: UpdogOutage; end: number } | null = null;
  for (const outage of outages) {
    if (!outage.end) continue;
    if (now - outage.end >= RECENT_RESOLVED_MS) continue;
    if (!best || outage.end > best.end) best = { outage, end: outage.end };
  }
  if (best) {
    const inc = best.outage.linked_status_page_incidents?.[0];
    return {
      level: "degraded",
      incidentUrl: inc?.url ?? UPDOG_PAGE,
      outageStart: inc?.start ?? best.outage.start,
      outageEnd: inc?.end ?? best.end,
    };
  }

  return { level: "operational" };
}

// ── HTTP fetch ───────────────────────────────────────────────────────────────

export async function fetchAnthropicStatus(
  signal?: AbortSignal,
  fetchImpl: typeof fetch = fetch,
): Promise<AnthropicStatus> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  const onParentAbort = () => controller.abort();
  signal?.addEventListener("abort", onParentAbort, { once: true });
  try {
    const resp = await fetchImpl(UPDOG_URL, { signal: controller.signal });
    if (!resp.ok) return { level: "unknown" };
    const data = (await resp.json()) as UpdogPayload;
    return selectStatusFromUpdog(data);
  } catch {
    return { level: "unknown" };
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener("abort", onParentAbort);
  }
}

// ── Shared cache + lock coordination ─────────────────────────────────────────

interface CachedStatus {
  status: AnthropicStatus;
  mtime: number;
}

async function readCache(): Promise<CachedStatus | null> {
  try {
    const [content, stats] = await Promise.all([
      readFile(CACHE_FILE, "utf8"),
      stat(CACHE_FILE),
    ]);
    return {
      status: JSON.parse(content) as AnthropicStatus,
      mtime: stats.mtimeMs,
    };
  } catch {
    return null;
  }
}

/** Atomic write: temp file + rename. Safe against concurrent readers. */
async function writeCache(status: AnthropicStatus): Promise<void> {
  await mkdir(CACHE_DIR, { recursive: true });
  await writeFile(CACHE_TMP, JSON.stringify(status), "utf8");
  await rename(CACHE_TMP, CACHE_FILE);
}

/**
 * Atomic O_EXCL lock. Returns an unlock fn, or null when another process
 * already holds the lock.
 */
async function tryLock(): Promise<(() => Promise<void>) | null> {
  await mkdir(CACHE_DIR, { recursive: true });

  // Clean up a lock left by a SIGKILL'd process.
  try {
    const lockStat = await stat(LOCK_FILE);
    if (Date.now() - lockStat.mtimeMs > LOCK_MAX_AGE) {
      await unlink(LOCK_FILE).catch(() => {});
    }
  } catch {
    /* lock doesn't exist — fine */
  }

  try {
    const fd = await open(LOCK_FILE, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY);
    await fd.close();
    return async () => {
      try {
        await unlink(LOCK_FILE);
      } catch {
        /* best-effort */
      }
    };
  } catch {
    return null;
  }
}

// ── In-memory dedupe + public API ────────────────────────────────────────────

let inflight: Promise<AnthropicStatus> | null = null;

/**
 * Get the current Anthropic status, honoring the shared on-disk cache and the
 * cross-process lock. Concurrent calls within a single process share a single
 * round-trip.
 *
 * Pass `parentSignal` (e.g. `ctx.signal`) to make cancellation cooperative.
 */
export function getAnthropicStatus(parentSignal?: AbortSignal): Promise<AnthropicStatus> {
  if (inflight) return inflight;
  inflight = (async () => {
    try {
      return await doGetAnthropicStatus(parentSignal);
    } finally {
      inflight = null;
    }
  })();
  return inflight;
}

async function doGetAnthropicStatus(parentSignal?: AbortSignal): Promise<AnthropicStatus> {
  const now = Date.now();
  const cached = await readCache();

  if (cached && now - cached.mtime < POLL_INTERVAL_MS) return cached.status;

  const unlock = await tryLock();
  if (!unlock) {
    // Another instance is updating — return what we have, marked stale if old.
    if (cached) return { ...cached.status, stale: now - cached.mtime > STALE_MS };
    return { level: "unknown", stale: true };
  }

  // We hold the lock — run the fetch with its own deadline and cancellation.
  const fetchController = new AbortController();
  const ttlTimer = setTimeout(() => fetchController.abort(), LOCK_OWNER_TTL);
  const onParentAbort = () => fetchController.abort();
  parentSignal?.addEventListener("abort", onParentAbort, { once: true });

  try {
    const result = await fetchAnthropicStatus(fetchController.signal);
    // `fetchAnthropicStatus` catches its own errors and returns `unknown`. We
    // treat "unknown" as a failed fetch — keep the previous cached value.
    if (result.level !== "unknown") {
      await writeCache(result);
      return result;
    }
    if (cached) return { ...cached.status, stale: now - cached.mtime > STALE_MS };
    return { level: "unknown", stale: true };
  } finally {
    clearTimeout(ttlTimer);
    parentSignal?.removeEventListener("abort", onParentAbort);
    await unlock();
  }
}
