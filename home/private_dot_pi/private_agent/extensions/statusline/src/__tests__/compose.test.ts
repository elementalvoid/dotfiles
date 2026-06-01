import { describe, it } from "node:test";
import assert from "node:assert/strict";

import {
  composeCentered,
  composeLeftCenterRight,
  composeLeftRight,
  ESC_RESET,
  safeTruncate,
  visibleWidth,
} from "../compose.ts";

describe("composeLeftCenterRight", () => {
  it("places the center at the geometric midpoint when it fits", () => {
    const line = composeLeftCenterRight("L", 1, "C", 1, "R", 1, 11);
    // Width 11 -> midpoint 5, so "C" lands at column 5
    assert.equal(visibleWidth(line), 11);
    assert.equal(line.indexOf("C"), 5);
    assert.equal(line[0], "L");
    assert.equal(line[line.length - 1], "R");
  });

  it("clamps the center leftward so it does not overlap right", () => {
    // Left is wide; midpoint would overlap right — center should push left.
    const line = composeLeftCenterRight(
      "LLLLLLLLL", 9, "CCC", 3, "RR", 2, 14,
    );
    assert.equal(visibleWidth(line), 14);
    // Right two chars are RR
    assert.ok(line.endsWith("RR"));
    // CCC appears somewhere after L block
    assert.ok(line.includes("CCC"));
  });

  it("falls back to two-pane layout when total width exceeds bound", () => {
    const line = composeLeftCenterRight("LL", 2, "CCCC", 4, "RR", 2, 5);
    // 2+4+2 > 5 → drop the center
    assert.equal(visibleWidth(line), 5);
    assert.ok(!line.includes("CCCC"));
    assert.ok(line.startsWith("LL"));
  });
});

describe("composeLeftRight", () => {
  it("pads between left and right exactly to width", () => {
    const line = composeLeftRight("L", 1, "R", 1, 10);
    assert.equal(visibleWidth(line), 10);
    assert.equal(line[0], "L");
    assert.equal(line[line.length - 1], "R");
  });

  it("truncates when input exceeds width and appends reset", () => {
    const line = composeLeftRight("LLLLLLLL", 8, "RRRR", 4, 5);
    assert.ok(line.endsWith(ESC_RESET));
  });
});

describe("composeCentered", () => {
  it("centers a single chunk", () => {
    const line = composeCentered("X", 1, 5);
    assert.equal(line, "  X");
    // width is the max column count; we only pad on the left side here.
  });
});

describe("safeTruncate", () => {
  it("returns input untouched when it fits", () => {
    const s = "hello";
    assert.equal(safeTruncate(s, 10), s);
  });

  it("appends an OSC 8 + SGR reset when truncation occurred", () => {
    const s = "abcdefghij";
    const out = safeTruncate(s, 4);
    assert.ok(out.endsWith(ESC_RESET), `missing reset: ${JSON.stringify(out)}`);
  });

  it("never leaves a dangling hyperlink open after truncation", () => {
    const link = "\x1b]8;;https://x.test\x1b\\label-that-is-pretty-long\x1b]8;;\x1b\\ tail";
    const out = safeTruncate(link, 5);
    assert.ok(out.endsWith(ESC_RESET));
  });
});
