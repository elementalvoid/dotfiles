/**
 * Unit tests for formatUsageQuota() — pure formatting, no network calls.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";

import { fmtQuotaAge, formatUsageQuota, parseRetryAfter, type UsageQuota } from "../usage-quota.ts";

describe("formatUsageQuota", () => {
  it("returns null when quota is null", () => {
    assert.strictEqual(formatUsageQuota(null), null);
  });

  it("returns null for an empty quota object", () => {
    assert.strictEqual(formatUsageQuota({}), null);
  });

  it("shows $used/$limit when extra_usage is enabled with a limit", () => {
    const quota: UsageQuota = {
      extra_usage: {
        is_enabled: true,
        monthly_limit: 20000,   // $200.00
        used_credits: 9178,     // $91.78
        utilization: 45.89,
      },
    };
    assert.strictEqual(formatUsageQuota(quota), "$91.78/$200.00");
  });

  it("shows $used when extra_usage is enabled but unlimited (no cap)", () => {
    const quota: UsageQuota = {
      extra_usage: {
        is_enabled: true,
        monthly_limit: null,
        used_credits: 500,  // $5.00
        utilization: 0,
      },
    };
    assert.strictEqual(formatUsageQuota(quota), "$5.00");
  });

  it("returns null when extra_usage is not enabled", () => {
    const quota: UsageQuota = {
      extra_usage: {
        is_enabled: false,
        monthly_limit: 10000,
        used_credits: 500,
        utilization: 5,
      },
    };
    assert.strictEqual(formatUsageQuota(quota), null);
  });

  it("falls back to five_hour when extra_usage absent", () => {
    const quota: UsageQuota = {
      five_hour: { utilization: 42.3, resets_at: "2026-01-01T12:00:00Z" },
    };
    assert.strictEqual(formatUsageQuota(quota), "42% (5h)");
  });

  it("falls back to seven_day when five_hour is zero", () => {
    const quota: UsageQuota = {
      five_hour: { utilization: 0, resets_at: "2026-01-01T12:00:00Z" },
      seven_day: { utilization: 31.7, resets_at: "2026-01-07T00:00:00Z" },
    };
    assert.strictEqual(formatUsageQuota(quota), "32% (7d)");
  });

  it("returns null when all utilisation values are zero", () => {
    const quota: UsageQuota = {
      five_hour: { utilization: 0, resets_at: "2026-01-01T12:00:00Z" },
      seven_day: { utilization: 0, resets_at: "2026-01-07T00:00:00Z" },
    };
    assert.strictEqual(formatUsageQuota(quota), null);
  });

  it("prefers extra_usage over rate-limit windows when both present", () => {
    const quota: UsageQuota = {
      five_hour: { utilization: 80, resets_at: "2026-01-01T12:00:00Z" },
      extra_usage: {
        is_enabled: true,
        monthly_limit: 5000,
        used_credits: 1234,
        utilization: 24.68,
      },
    };
    // Should show dollar format, not "80% (5h)"
    assert.strictEqual(formatUsageQuota(quota), "$12.34/$50.00");
  });

  it("rounds the utilisation percentage", () => {
    const quota: UsageQuota = {
      five_hour: { utilization: 46.6, resets_at: "2026-01-01T12:00:00Z" },
    };
    assert.strictEqual(formatUsageQuota(quota), "47% (5h)");
  });
});

describe("parseRetryAfter", () => {
  const DEFAULT = 5 * 60_000;
  const NOW = 1_700_000_000_000;

  it("returns default for null", () => {
    assert.strictEqual(parseRetryAfter(null, NOW), DEFAULT);
  });

  it("returns default for empty string", () => {
    assert.strictEqual(parseRetryAfter("", NOW), DEFAULT);
  });

  it("parses positive integer seconds", () => {
    assert.strictEqual(parseRetryAfter("120", NOW), 120_000);
  });

  it("rejects 0 — known buggy endpoint value", () => {
    assert.strictEqual(parseRetryAfter("0", NOW), DEFAULT);
  });

  it("rejects negative values", () => {
    assert.strictEqual(parseRetryAfter("-30", NOW), DEFAULT);
  });

  it("parses a future HTTP-date", () => {
    const futureMs = NOW + 90_000;
    const httpDate = new Date(futureMs).toUTCString();
    const result = parseRetryAfter(httpDate, NOW);
    // Allow ±1 s for rounding in Date.toUTCString (truncates to seconds).
    assert.ok(Math.abs(result - 90_000) <= 1_000, `expected ~90000 ms, got ${result}`);
  });

  it("returns default for a past HTTP-date", () => {
    const pastDate = new Date(NOW - 60_000).toUTCString();
    assert.strictEqual(parseRetryAfter(pastDate, NOW), DEFAULT);
  });

  it("returns default for garbage input", () => {
    assert.strictEqual(parseRetryAfter("not-a-number", NOW), DEFAULT);
  });
});

describe("fmtQuotaAge", () => {
  const NOW = 1_700_000_000_000;

  it("returns 'just now' when under a minute", () => {
    assert.strictEqual(fmtQuotaAge(NOW - 30_000, NOW), "just now");
  });

  it("returns 'just now' at exactly 0ms elapsed", () => {
    assert.strictEqual(fmtQuotaAge(NOW, NOW), "just now");
  });

  it("returns Xm for minutes", () => {
    assert.strictEqual(fmtQuotaAge(NOW - 3 * 60_000, NOW), "3m");
    assert.strictEqual(fmtQuotaAge(NOW - 59 * 60_000 - 59_000, NOW), "59m");
  });

  it("switches to Xh at one hour", () => {
    assert.strictEqual(fmtQuotaAge(NOW - 60 * 60_000, NOW), "1h");
    assert.strictEqual(fmtQuotaAge(NOW - 2.5 * 60 * 60_000, NOW), "2h");
  });
});
