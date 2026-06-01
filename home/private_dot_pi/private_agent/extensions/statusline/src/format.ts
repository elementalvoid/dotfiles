/**
 * Pure formatting helpers.
 *
 * Everything in this file must stay side-effect free and synchronous so it can
 * be unit tested without any pi/TUI dependencies.
 */

import { basename } from "node:path";
import { homedir } from "node:os";

// ── Cwd shortening (p10k-style) ──────────────────────────────────────────────

export interface ShortenedPath {
  /** Rendered plain text, for width calculations. */
  plain: string;
  /** Leading prefix: "~", "/" or "". */
  prefix: string;
  /** Individual segments, each marked as truncated or not. */
  parts: Array<{ text: string; truncated: boolean }>;
}

/**
 * Shorten a cwd so the rendered plain text fits within `threshold` columns.
 *
 * Strategy: replace `$HOME` with `~`, then try progressively shorter
 * truncations (3 → 2 → 1 chars) for every non-terminal segment. If nothing
 * fits we fall back to `/<basename>` — preserving the tilde if the original
 * path was inside `$HOME`.
 */
export function shortenCwd(sessionCwd: string, threshold: number): ShortenedPath {
  const home = homedir();
  // Guard against substring collisions like "/home" vs "/homework".
  const inHome =
    sessionCwd === home ||
    (sessionCwd.startsWith(home) && sessionCwd[home.length] === "/");
  const withHome = inHome ? `~${sessionCwd.slice(home.length)}` : sessionCwd;

  let prefix: string;
  let segments: string[];

  if (withHome === "~") {
    return { plain: "~", prefix: "~", parts: [] };
  } else if (withHome.startsWith("~/")) {
    prefix = "~";
    segments = withHome.slice(2).split("/").filter(Boolean);
  } else if (withHome.startsWith("/")) {
    prefix = "/";
    segments = withHome.slice(1).split("/").filter(Boolean);
  } else {
    prefix = "";
    segments = withHome.split("/").filter(Boolean);
  }

  const buildPlain = (segs: string[]): string =>
    prefix === "~" ? (segs.length === 0 ? "~" : `~/${segs.join("/")}`) :
    prefix === "/" ? `/${segs.join("/")}` :
    segs.join("/");

  if (segments.length === 0) {
    return { plain: prefix || withHome, prefix, parts: [] };
  }

  if (buildPlain(segments).length <= threshold) {
    return {
      plain: buildPlain(segments),
      prefix,
      parts: segments.map(s => ({ text: s, truncated: false })),
    };
  }

  for (const truncLen of [3, 2, 1]) {
    const parts = segments.map((seg, i) => {
      const isLast = i === segments.length - 1;
      if (!isLast && seg.length > truncLen) {
        return { text: seg.slice(0, truncLen), truncated: true };
      }
      return { text: seg, truncated: false };
    });
    const plain = buildPlain(parts.map(p => p.text));
    if (plain.length <= threshold) {
      return { plain, prefix, parts };
    }
  }

  // Final fallback — single basename. Preserve `~` if we were inside $HOME.
  const base = basename(sessionCwd) || "/";
  const fallbackPrefix = inHome ? "~" : "/";
  return {
    plain: `${fallbackPrefix}/${base}`,
    prefix: fallbackPrefix,
    parts: [{ text: base, truncated: false }],
  };
}

// ── Numeric formatting ───────────────────────────────────────────────────────

export function fmtTokens(n: number): string {
  if (n >= 1_000_000) {
    const v = n / 1_000_000;
    return v >= 10 ? `${Math.round(v)}M` : `${v.toFixed(1)}M`;
  }
  if (n >= 1_000) {
    const v = n / 1_000;
    return v >= 10 ? `${Math.round(v)}k` : `${v.toFixed(1)}k`;
  }
  return `${n}`;
}

export function fmtDateTime(ms: number, now: Date = new Date()): string {
  const d = new Date(ms);
  const isToday = d.toDateString() === now.toDateString();
  const time = d.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  if (isToday) return time;
  return `${d.toLocaleDateString([], { month: "short", day: "numeric" })} ${time}`;
}

// ── Terminal escape helpers ──────────────────────────────────────────────────

/**
 * Strip control characters that would break OSC 8 / ANSI state or allow an
 * untrusted upstream feed (updog.ai) to inject terminal control sequences.
 */
export function sanitizeText(s: string): string {
  // eslint-disable-next-line no-control-regex
  return s.replace(/[\x00-\x1f\x7f]/g, "");
}

export function sanitizeUrl(url: string): string {
  // Same rule, but also reject obviously-malformed inputs early.
  return sanitizeText(url).trim();
}

/**
 * OSC 8 hyperlink. Both `url` and `text` are sanitized — `url` because it may
 * originate from a third-party JSON feed, `text` because the caller sometimes
 * embeds user-provided data (branch names) into the label.
 *
 * NOTE: callers must avoid truncating the returned string inside a hyperlink
 * segment. See `compose.ts` for width-aware placement.
 */
export function hyperlink(url: string, styledText: string): string {
  const safeUrl = sanitizeUrl(url);
  return `\x1b]8;;${safeUrl}\x1b\\${styledText}\x1b]8;;\x1b\\`;
}
