/**
 * Singleton refcounted poller for Anthropic status.
 *
 * Ensures that no matter how many sessions subscribe (e.g. `/new`, `/fork`,
 * `/resume` all run `session_start` and previously leaked per-session
 * intervals) there is only one `setInterval` running process-wide, and one
 * network round-trip per cycle.
 *
 * Subscribers receive the latest known status immediately and then every poll
 * tick. The interval is torn down when the last subscriber unsubscribes.
 */

import {
  getAnthropicStatus,
  POLL_INTERVAL_MS,
  type AnthropicStatus,
} from "./anthropic-status.ts";

type Listener = (status: AnthropicStatus) => void;

let listeners = new Set<Listener>();
let timer: ReturnType<typeof setInterval> | null = null;
let latest: AnthropicStatus = { level: "unknown" };
let fetching = false;

async function refresh(): Promise<void> {
  if (fetching) return;
  fetching = true;
  try {
    latest = await getAnthropicStatus();
    // Copy the set first — listeners may unsubscribe themselves during
    // notification, which would mutate the set mid-iteration.
    for (const l of [...listeners]) {
      try {
        l(latest);
      } catch {
        /* never let a listener tear down the poller */
      }
    }
  } finally {
    fetching = false;
  }
}

export function subscribeAnthropicStatus(listener: Listener): () => void {
  listeners.add(listener);

  // Emit the currently-known value immediately so subscribers render without
  // waiting a full poll cycle.
  queueMicrotask(() => {
    if (listeners.has(listener)) listener(latest);
  });

  // First subscriber: kick off the initial fetch and start the interval.
  if (listeners.size === 1) {
    void refresh();
    timer = setInterval(() => {
      void refresh();
    }, POLL_INTERVAL_MS);
    // Don't keep a short-lived process (e.g. `pi -p`) alive just for polling.
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
export function __resetPollerForTests(): void {
  if (timer !== null) clearInterval(timer);
  timer = null;
  listeners = new Set();
  latest = { level: "unknown" };
  fetching = false;
}
