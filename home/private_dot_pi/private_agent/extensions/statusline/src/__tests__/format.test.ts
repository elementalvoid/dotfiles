import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { homedir } from "node:os";

import {
  fmtDateTime,
  fmtTokens,
  hyperlink,
  sanitizeText,
  sanitizeUrl,
  shortenCwd,
} from "../format.ts";

describe("fmtTokens", () => {
  it("renders raw integers below 1k", () => {
    assert.equal(fmtTokens(0), "0");
    assert.equal(fmtTokens(999), "999");
  });

  it("uses one decimal place in the [1k, 10k) range", () => {
    assert.equal(fmtTokens(1000), "1.0k");
    assert.equal(fmtTokens(1500), "1.5k");
    // 9999 / 1000 = 9.999 — keeps one decimal (renders as 10.0k).
    assert.equal(fmtTokens(9999), "10.0k");
  });

  it("drops the decimal once the integer part is ≥ 10", () => {
    assert.equal(fmtTokens(10000), "10k");
    assert.equal(fmtTokens(10500), "11k");
    assert.equal(fmtTokens(999_000), "999k");
  });

  it("switches to M at a million", () => {
    assert.equal(fmtTokens(1_000_000), "1.0M");
    assert.equal(fmtTokens(1_500_000), "1.5M");
    assert.equal(fmtTokens(10_500_000), "11M");
  });
});

describe("fmtDateTime", () => {
  it("returns time-only for today", () => {
    const now = new Date("2025-03-15T12:00:00");
    const out = fmtDateTime(new Date("2025-03-15T09:30:00").getTime(), now);
    assert.match(out, /\d{1,2}:\d{2}/);
    assert.doesNotMatch(out, /Mar/);
  });

  it("includes month + day when the date differs", () => {
    const now = new Date("2025-03-15T12:00:00");
    const out = fmtDateTime(new Date("2025-03-10T09:30:00").getTime(), now);
    assert.match(out, /Mar/);
    assert.match(out, /\d{1,2}:\d{2}/);
  });
});

describe("sanitizeText / sanitizeUrl", () => {
  it("strips control characters including ESC", () => {
    assert.equal(sanitizeText("hello\x1b]8;; evil\x1b\\ world"), "hello]8;; evil\\ world");
    assert.equal(sanitizeText("line\nbreak\r\nhere"), "linebreakhere");
  });

  it("keeps normal printable ASCII and Unicode", () => {
    assert.equal(sanitizeText("hello · world 🚀"), "hello · world 🚀");
  });

  it("trims whitespace around urls", () => {
    assert.equal(sanitizeUrl("  https://x.test  "), "https://x.test");
  });
});

describe("hyperlink", () => {
  it("wraps the styled text with an OSC 8 link", () => {
    const h = hyperlink("https://x.test", "label");
    assert.ok(h.includes("https://x.test"));
    assert.ok(h.includes("\x1b]8;;"));
    assert.ok(h.endsWith("\x1b]8;;\x1b\\"));
    assert.ok(h.includes("label"));
  });

  it("sanitizes an injection attempt in the URL", () => {
    const h = hyperlink("https://x.test\x1b\\evil", "label");
    // ESC and subsequent backslash are stripped; the bare payload remains text.
    assert.ok(!h.match(/https:\/\/x\.test\x1b/));
  });
});

describe("shortenCwd", () => {
  const home = homedir();

  it("returns `~` unchanged when cwd is home", () => {
    const r = shortenCwd(home, 60);
    assert.equal(r.plain, "~");
    assert.equal(r.prefix, "~");
    assert.deepEqual(r.parts, []);
  });

  it("leaves a short path inside home untruncated", () => {
    const r = shortenCwd(`${home}/foo/bar`, 60);
    assert.equal(r.plain, "~/foo/bar");
    assert.equal(r.parts.every(p => !p.truncated), true);
  });

  it("does not collide on home-prefix substring", () => {
    // "/homework" must not be treated as "~work".
    const hw = home + "work";
    const r = shortenCwd(hw, 60);
    assert.ok(!r.plain.startsWith("~"), `got ${r.plain}`);
  });

  it("truncates intermediate segments when over threshold", () => {
    const long = `${home}/aaaaaaaaaa/bbbbbbbbbb/cccccccccc/dddddddddd/eeeeeeeeee`;
    const r = shortenCwd(long, 20);
    assert.ok(r.plain.length <= 20, `plain too long: ${r.plain}`);
    // Last segment is preserved in full.
    const last = r.parts[r.parts.length - 1];
    assert.equal(last.truncated, false);
    assert.equal(last.text, "eeeeeeeeee");
  });

  it("falls back to /<basename> when nothing fits", () => {
    // Every segment already length 1 and it still doesn't fit.
    const r = shortenCwd("/a/b/c/d/e/f/g/h/i/final", 3);
    assert.equal(r.parts.length, 1);
    assert.equal(r.parts[0].text, "final");
    assert.equal(r.prefix, "/");
  });

  it("preserves tilde in the final fallback for home-relative paths", () => {
    const deep = `${home}/${"x".repeat(20)}/${"y".repeat(20)}/${"z".repeat(20)}/final`;
    const r = shortenCwd(deep, 3);
    assert.equal(r.prefix, "~");
    assert.equal(r.parts[0].text, "final");
  });
});
