/**
 * End-to-end component tests. Stubs the theme with an identity colorizer
 * (with a marker for `bg`) so we can both read the visible content and prove
 * that the banner background fn was applied.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";

import {
  StatuslineRoot,
  type RenderTheme,
  type StatuslineInputs,
} from "../components.ts";
import { visibleWidth } from "../compose.ts";

// Embed the slot name in an APC sequence (ESC _ ... ESC \). pi-tui's
// visibleWidth strips APC sequences as zero-width (same path used by
// CURSOR_MARKER), so the marker is invisible to width math but still
// inspectable from the test by regex.
const BG_MARKER_RE = /\x1b_BG=([^\x1b]+)\x1b\\/;
const markBg = (slot: string, text: string) =>
  `\x1b_BG=${slot}\x1b\\${text}\x1b[0m`;

const identityTheme: RenderTheme = {
  fg: (_slot, text) => text,   // slots tested by hasBgMarker / explicit checks only
  bg: (slot, text) => markBg(slot, text),
};

// Theme that records fg slot usage so we can assert on which slot renders timeSuffix.
function recordingTheme(): { theme: RenderTheme; calls: Array<[string, string]> } {
  const calls: Array<[string, string]> = [];
  return {
    theme: {
      fg: (slot, text) => { calls.push([slot, text]); return text; },
      bg: (_slot, text) => text,
    },
    calls,
  };
}

function hasBgMarker(s: string, slot: string): boolean {
  const m = s.match(BG_MARKER_RE);
  return m !== null && m[1] === slot;
}

function baseInputs(overrides: Partial<StatuslineInputs> = {}): StatuslineInputs {
  return {
    inputTok: 1234,
    outputTok: 567,
    cacheTok: 8_900,
    totalCost: 0.0421,
    ctxPctNum: 12.3,
    ctxWindow: 200_000,
    modelId: "sonnet-4-5",
    thinking: "medium",
    sessionCwd: "/tmp/project",
    branch: "main",
    pr: null,
    webSearch: null,
    anthropic: { level: "operational" },
    ...overrides,
  };
}

function stripAnsi(s: string): string {
  // eslint-disable-next-line no-control-regex
  return s.replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/g, "")
          // eslint-disable-next-line no-control-regex
          .replace(/\x1b\[[0-9;]*[A-Za-z]/g, "")
          // Our private bg marker (above) — strip for visible-text assertions.
          .replace(BG_MARKER_RE, "");
}

function render(inputs: StatuslineInputs, width = 120): string[] {
  const root = new StatuslineRoot(identityTheme);
  root.setData(inputs);
  return root.render(width);
}

describe("StatuslineRoot — operational", () => {
  const lines = render(baseInputs());

  it("returns exactly two lines when there is no active outage", () => {
    assert.equal(lines.length, 2);
  });

  it("Text-backed children pad to full width", () => {
    // pi-tui's Text always pads to the full requested width — proves we are
    // actually delegating to the toolkit rather than re-implementing it.
    for (const line of lines) {
      assert.equal(visibleWidth(line), 120, `line not full-width: ${JSON.stringify(line)}`);
    }
  });

  it("line 1 contains token counts, context %, cost, model, and ● dot", () => {
    const plain = stripAnsi(lines[0]);
    assert.match(plain, /↑1\.2k/);
    assert.match(plain, /↓567/);
    assert.match(plain, /12\.3%\/200k/);
    assert.match(plain, /\$0\.042/);
    assert.match(plain, /sonnet-4-5/);
    assert.match(plain, /medium/);
    assert.match(plain, /● Anthropic/);
  });

  it("line 2 shows cwd and branch", () => {
    const plain = stripAnsi(lines[1]);
    assert.match(plain, /\/tmp\/project/);
    assert.match(plain, /⎇ main/);
  });

  it("status is wrapped in an OSC 8 hyperlink to updog", () => {
    assert.match(lines[0], /\x1b\]8;;https:\/\/updog\.ai\/status\/anthropic\x1b\\/);
  });

  it("does NOT apply the toolErrorBg background when operational", () => {
    for (const line of lines) {
      assert.ok(!hasBgMarker(line, "toolErrorBg"),
        `unexpected bg in: ${JSON.stringify(line)}`);
    }
  });
});

describe("StatuslineRoot — active outage", () => {
  const lines = render(baseInputs({
    anthropic: {
      level: "outage",
      title: "Elevated error rates on claude-sonnet-4-5",
      incidentUrl: "https://status.anthropic.com/incidents/abc",
      outageStart: new Date("2025-04-17T08:15:00").getTime(),
    },
  }));

  it("returns three lines with the banner in the middle", () => {
    assert.equal(lines.length, 3);
  });

  it("all three lines pad to full width", () => {
    // The banner is now Box-backed: full width with painted background.
    for (const line of lines) {
      assert.equal(visibleWidth(line), 120, `line not full-width: ${JSON.stringify(line)}`);
    }
  });

  it("banner is wrapped in toolErrorBg across the whole line", () => {
    assert.ok(hasBgMarker(lines[1], "toolErrorBg"),
      `missing bg marker in: ${JSON.stringify(lines[1])}`);
    // Visible content survives.
    const plain = stripAnsi(lines[1]);
    assert.match(plain, /✖ Elevated error rates/);
    assert.match(plain, /since /);
  });

  it("'since' timestamp uses the muted slot (neutral gray, not dim-red)", () => {
    const { theme, calls } = recordingTheme();
    const r = new StatuslineRoot(theme);
    r.setData(baseInputs({
      anthropic: {
        level: "outage",
        title: "Test outage",
        incidentUrl: "https://x",
        outageStart: Date.now() - 45 * 60_000,
      },
    }));
    r.render(120);
    const sinceCall = calls.find(([, text]) => text.includes("since"));
    assert.ok(sinceCall, "expected a fg() call containing 'since'");
    assert.equal(sinceCall![0], "muted", `expected slot 'muted', got '${sinceCall![0]}'`);
  });

  it("status dot on line 1 switches to ✖ and uses the incident URL", () => {
    const plain = stripAnsi(lines[0]);
    assert.match(plain, /✖ Anthropic/);
    assert.ok(lines[0].includes("https://status.anthropic.com/incidents/abc"));
  });
});

describe("StatuslineRoot — banner toggles on/off correctly", () => {
  it("removes the banner when status returns to operational", () => {
    const root = new StatuslineRoot(identityTheme);
    root.setData(baseInputs({
      anthropic: { level: "outage", title: "x", outageStart: Date.now() },
    }));
    assert.equal(root.render(120).length, 3);

    root.setData(baseInputs({ anthropic: { level: "operational" } }));
    assert.equal(root.render(120).length, 2);
  });

  it("re-adds the banner when status flips back to outage", () => {
    const root = new StatuslineRoot(identityTheme);
    root.setData(baseInputs());
    assert.equal(root.render(120).length, 2);

    root.setData(baseInputs({
      anthropic: { level: "outage", title: "y", outageStart: Date.now() },
    }));
    assert.equal(root.render(120).length, 3);
  });

  it("does not show a banner for stale data even if level is outage", () => {
    const lines = render(baseInputs({
      anthropic: { level: "outage", title: "z", stale: true, outageStart: Date.now() },
    }));
    assert.equal(lines.length, 2);
  });
});

describe("StatuslineRoot — caching", () => {
  it("re-renders only when inputs change", () => {
    const root = new StatuslineRoot(identityTheme);
    root.setData(baseInputs());
    const a = root.render(120);
    // Same inputs → same identical strings (Text caches by text+width).
    const b = root.render(120);
    assert.deepEqual(a, b);
    assert.equal(a[0], b[0]);
    assert.equal(a[1], b[1]);
  });

  it("invalidate() forces a rebuild", () => {
    const root = new StatuslineRoot(identityTheme);
    root.setData(baseInputs());
    root.render(120);
    // After invalidate, a new render should still produce identical output
    // (theme + inputs unchanged) — but it must have actually re-executed.
    root.invalidate();
    const after = root.render(120);
    assert.equal(visibleWidth(after[0]), 120);
  });
});

describe("StatuslineRoot — PR + web-search adornments", () => {
  const lines = render(baseInputs({
    pr: { number: 42, url: "https://github.com/owner/repo/pull/42" },
    webSearch: {
      enabled: true,
      model: "claude-haiku",
      thinking: "low",
      location: { type: "approximate", country: "US" },
    },
  }));

  it("shows PR label and links it", () => {
    const plain = stripAnsi(lines[1]);
    assert.match(plain, /PR #42/);
    assert.ok(lines[1].includes("https://github.com/owner/repo/pull/42"));
  });

  it("renders web-search details on the right of line 2", () => {
    const plain = stripAnsi(lines[1]);
    assert.match(plain, /haiku/);
    assert.match(plain, /\(low\)/);
    assert.match(plain, /·US/);
  });
});

describe("StatuslineRoot — Anthropic usage display", () => {
  const quota = {
    extra_usage: { is_enabled: true, monthly_limit: 75000, used_credits: 132, utilization: 0.176 },
  };

  it("shows $used/$limit and age when enabled with data", () => {
    const plain = stripAnsi(render(baseInputs({
      usageEnabled: true,
      usageQuota: quota,
      usageLastUpdated: Date.now(),
    }))[0]);
    assert.match(plain, /\$1\.32\/\$750\.00/);
    assert.match(plain, /· just now/);
  });

  it("shows --/-- when enabled but no data yet (no age)", () => {
    const plain = stripAnsi(render(baseInputs({
      usageEnabled: true,
      usageQuota: null,
      usageLastUpdated: null,
    }))[0]);
    assert.match(plain, /--\/--/);
    assert.doesNotMatch(plain, /just now|\dm|\dh/);
  });

  it("shows neither usage nor age when disabled", () => {
    const plain = stripAnsi(render(baseInputs({
      usageEnabled: false,
      usageQuota: null,
      usageLastUpdated: null,
    }))[0]);
    assert.doesNotMatch(plain, /--\/--|\$1\.32/);
    assert.doesNotMatch(plain, /just now/);
  });

  it("hides the age even if a stale lastUpdated lingers after disabling", () => {
    // Regression: disabling usage cleared the quota but left usageLastUpdated
    // set, so "· just now" kept rendering. Age must be gated on usageEnabled.
    const plain = stripAnsi(render(baseInputs({
      usageEnabled: false,
      usageQuota: null,
      usageLastUpdated: Date.now(),
    }))[0]);
    assert.doesNotMatch(plain, /just now/);
    assert.match(plain, /● Anthropic/);
  });
});

describe("StatuslineRoot — extension statuses (LSP/MCP)", () => {
  it("renders pre-styled extension statuses centered on line 2", () => {
    const lines = render(baseInputs({
      extensionStatuses: ["LSP", "MCP: 1/1 servers"],
    }));
    const plain = stripAnsi(lines[1]);
    assert.match(plain, /LSP/);
    assert.match(plain, /MCP: 1\/1 servers/);
    // Centered: there is cwd text to its left and trailing padding to its right.
    const lspIdx = plain.indexOf("LSP");
    assert.ok(lspIdx > visibleWidth(" /tmp/project"), "statuses should sit past the left cwd segment");
  });

  it("shows extension statuses alongside web-search", () => {
    const lines = render(baseInputs({
      extensionStatuses: ["LSP"],
      webSearch: {
        enabled: true,
        model: "claude-haiku",
        thinking: "low",
        location: null,
      },
    }));
    const plain = stripAnsi(lines[1]);
    assert.match(plain, /LSP/);
    assert.match(plain, /haiku/);
  });

  it("renders nothing extra when there are no extension statuses", () => {
    const lines = render(baseInputs({ extensionStatuses: [] }));
    // Line 2 still pads to full width and contains the cwd.
    assert.equal(visibleWidth(lines[1]), 120);
    assert.match(stripAnsi(lines[1]), /project/);
  });
});

describe("StatuslineRoot — degenerate inputs and security", () => {
  it("handles unknown model", () => {
    const lines = render(baseInputs({ modelId: null }));
    assert.match(stripAnsi(lines[0]), /no-model/);
  });

  it("handles missing context usage", () => {
    const lines = render(baseInputs({ ctxPctNum: null, ctxWindow: undefined }));
    assert.match(stripAnsi(lines[0]), /\?%\/\?/);
  });

  it("handles no git branch", () => {
    const lines = render(baseInputs({ branch: null }));
    assert.doesNotMatch(stripAnsi(lines[1]), /⎇/);
  });

  it("never overflows narrow widths", () => {
    for (const width of [40, 60, 80]) {
      const lines = render(baseInputs(), width);
      for (const line of lines) {
        assert.ok(visibleWidth(line) <= width,
          `width=${width}, got ${visibleWidth(line)}: ${JSON.stringify(line)}`);
      }
    }
  });

  it("sanitizes a malicious incident title (no ESC survives)", () => {
    const lines = render(baseInputs({
      anthropic: {
        level: "outage",
        title: "pwn\x1b[31mX",
        incidentUrl: "https://x.test",
        outageStart: Date.now(),
      },
    }));
    assert.ok(!lines[1].includes("\x1b[31m"), `injection survived: ${lines[1]}`);
  });

  it("sanitizes a malicious branch name", () => {
    const lines = render(baseInputs({ branch: "main\x1b[31m; rm -rf" }));
    assert.match(stripAnsi(lines[1]), /main\[31m; rm -rf/);
    assert.ok(!lines[1].includes("\x1b[31m"));
  });
});

describe("StatuslineRoot — stale cache indicator", () => {
  it("uses the hollow ○ dot when stale", () => {
    const lines = render(baseInputs({
      anthropic: { level: "operational", stale: true },
    }));
    assert.match(stripAnsi(lines[0]), /○ Anthropic/);
  });
});
