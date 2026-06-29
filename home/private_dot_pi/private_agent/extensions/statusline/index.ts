/**
 * Statusline Extension
 *
 * Replaces the default footer with a custom status line showing:
 *   Line 1 left:   ↑in ↓out 󱐋cache  ctx%/ctxSize  $cost
 *   Line 1 center: ● Anthropic  $used/$budget  (green/yellow/red — updog.ai)
 *   Line 1 right:  󱙺 model (thinking)
 *   Line 2:        ✖ Incident title  (full-width red banner, only when active)
 *   Line 2/3 left: ~/cwd  ⎇ branch  PR #N (hyperlink)
 *   Line 2/3 right: web-search status (when enabled)
 *
 * Most of the real work lives in `./src/*`. This file only wires pi events to
 * the component tree.
 */

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";

import type { AnthropicStatus } from "./src/anthropic-status.ts";
import { subscribeAnthropicStatus } from "./src/poller.ts";
import type { UsageQuota } from "./src/usage-quota.ts";
import { subscribeUsageQuota } from "./src/usage-quota.ts";
import { PrCache } from "./src/pr-cache.ts";
import { StatuslineRoot, type WebSearchState } from "./src/components.ts";

// ── Config ────────────────────────────────────────────────────────────────────

const CONFIG_FILE = join(homedir(), ".pi", "agent", "extensions", "statusline", "config.json");

interface StatuslineConfig {
  /** Set false to hide API usage spend from the center widget. Default: true. */
  anthropicUsage?: boolean;
}

async function loadConfig(): Promise<StatuslineConfig> {
  try {
    const raw = await readFile(CONFIG_FILE, "utf-8");
    return JSON.parse(raw) as StatuslineConfig;
  } catch {
    return {};
  }
}

async function saveConfig(cfg: StatuslineConfig): Promise<void> {
  await mkdir(join(homedir(), ".pi", "agent", "extensions", "statusline"), { recursive: true });
  await writeFile(CONFIG_FILE, JSON.stringify(cfg, null, 2) + "\n", "utf-8");
}

// ── Mock scenarios for /statusline anthropic-status-mock ─────────────────────

const MOCK_SCENARIOS: Record<string, { label: string; status: AnthropicStatus }> = {
  operational: {
    label: "● Operational  (green dot, no banner)",
    status: { level: "operational" },
  },
  degraded: {
    label: "▲ Degraded  (yellow triangle, recently resolved)",
    status: {
      level: "degraded",
      incidentUrl: "https://status.anthropic.com/incidents/mock",
      outageStart: Date.now() - 90 * 60_000,  // started 90 min ago
      outageEnd:   Date.now() - 20 * 60_000,  // resolved 20 min ago
    },
  },
  outage: {
    label: "✖ Active outage  (red dot + full-width banner)",
    status: {
      level: "outage",
      title: "Elevated API error rates on claude-sonnet-4-5",
      incidentUrl: "https://status.anthropic.com/incidents/mock",
      outageStart: Date.now() - 45 * 60_000,  // started 45 min ago
    },
  },
  stale: {
    label: "○ Stale cache  (hollow dot, last data too old to trust)",
    status: { level: "operational", stale: true },
  },
  unknown: {
    label: "○ Unknown  (hollow muted dot, fetch failed)",
    status: { level: "unknown" },
  },
};

const MOCK_KEYS = Object.keys(MOCK_SCENARIOS);

export default function (pi: ExtensionAPI) {
  const prCache = new PrCache(pi.exec);
  let webSearch: WebSearchState | null = null;
  let anthropicStatus: AnthropicStatus = { level: "unknown" };
  let usageQuota: UsageQuota | null = null;

  // When non-null, overrides the real polled status. Cleared by "reset".
  let mockStatus: AnthropicStatus | null = null;

  // Stored so the command (registered at factory level) can trigger a repaint.
  // Overwritten each time session_start fires; only the active session matters.
  let requestRender: () => void = () => {};

  // Usage-quota poller unsubscribe handle. Null when the feature is disabled.
  let usageUnsubscribe: (() => void) | null = null;
  let usageLastUpdated: number | null = null;
  let usageError: string | null = null;

  pi.events.on("web-search:state", (state: unknown) => {
    webSearch = state as WebSearchState;
  });

  // ── /footer:anthropic-status-test ─────────────────────────────────────────

  pi.registerCommand("statusline", {
    description:
      "Statusline controls. Subcommands: " +
      "anthropic-status-mock [key|reset], " +
      "anthropic-usage [on|off].",

    getArgumentCompletions(prefix: string): AutocompleteItem[] {
      const spaceAt = prefix.indexOf(" ");
      const sub  = spaceAt === -1 ? prefix : prefix.slice(0, spaceAt);
      const rest = spaceAt === -1 ? "" : prefix.slice(spaceAt + 1);

      // Top-level subcommand list.
      if (spaceAt === -1) {
        return [
          { value: "anthropic-status-mock", label: "anthropic-status-mock  — mock Anthropic status dot" },
          { value: "anthropic-usage",       label: "anthropic-usage  — toggle usage spend in center widget" },
        ].filter(i => i.value.startsWith(prefix));
      }

      if (sub === "anthropic-status-mock") {
        return [...MOCK_KEYS, "reset"]
          .filter(k => k.startsWith(rest))
          .map(k => ({
            value: `anthropic-status-mock ${k}`,
            label: k === "reset" ? "reset  (restore real status)" : MOCK_SCENARIOS[k].label,
          }));
      }

      if (sub === "anthropic-usage") {
        return ["on", "off"]
          .filter(v => v.startsWith(rest))
          .map(v => ({ value: `anthropic-usage ${v}`, label: v }));
      }

      return [];
    },

    handler: async (args, ctx) => {
      const parts = (args ?? "").trim().split(/\s+/).filter(Boolean);
      const sub = parts[0];
      const val = parts[1]?.toLowerCase();

      // ── /statusline anthropic-usage [on|off] ─────────────────────────
      if (sub === "anthropic-usage") {
        if (val === "off") {
          usageUnsubscribe?.();
          usageUnsubscribe = null;
          usageQuota = null;
          usageLastUpdated = null;
          usageError = null;
          requestRender();
          const cfg = await loadConfig();
          await saveConfig({ ...cfg, anthropicUsage: false });
          ctx.ui.notify("Anthropic usage display: off", "info");
          return;
        }
        if (val === "on") {
          if (!usageUnsubscribe) {
            usageUnsubscribe = subscribeUsageQuota(({ quota, lastUpdated, error }) => {
              usageQuota = quota;
              usageLastUpdated = lastUpdated;
              usageError = error;
              requestRender();
            });
          }
          const cfg = await loadConfig();
          await saveConfig({ ...cfg, anthropicUsage: true });
          ctx.ui.notify("Anthropic usage display: on", "info");
          return;
        }
        // No value — report current state.
        ctx.ui.notify(
          `Anthropic usage display: ${usageUnsubscribe ? "on" : "off"}`,
          "info",
        );
        return;
      }

      // ── /statusline anthropic-status-mock [key|reset] ─────────────────
      // Accept both `/statusline anthropic-status-mock outage` and the short
      // form `/statusline outage` for backwards compat.
      const mockArg = (sub === "anthropic-status-mock" ? val : sub)?.toLowerCase();

      if (mockArg && mockArg !== "reset" && MOCK_KEYS.includes(mockArg)) {
        mockStatus = MOCK_SCENARIOS[mockArg].status;
        requestRender();
        ctx.ui.notify(`Footer mock → ${MOCK_SCENARIOS[mockArg].label}`, "info");
        return;
      }

      if (mockArg === "reset") {
        mockStatus = null;
        requestRender();
        ctx.ui.notify("Footer mock cleared — showing real Anthropic status", "info");
        return;
      }

      // No recognised arg — interactive picker for the status mock.
      const items = [
        { value: "reset", label: "reset", description: "Restore real polled status" },
        ...MOCK_KEYS.map(k => ({
          value: k,
          label: k,
          description: MOCK_SCENARIOS[k].label,
        })),
      ];

      const choice = await ctx.ui.select(
        "Anthropic status mock",
        items.map(i => `${i.label}  —  ${i.description}`),
      );

      if (choice == null) return;

      const matched = items.find(i => choice.startsWith(i.label));
      if (!matched) return;

      if (matched.value === "reset") {
        mockStatus = null;
        requestRender();
        ctx.ui.notify("Footer mock cleared — showing real Anthropic status", "info");
      } else {
        mockStatus = MOCK_SCENARIOS[matched.value].status;
        requestRender();
        ctx.ui.notify(`Footer mock → ${MOCK_SCENARIOS[matched.value].label}`, "info");
      }
    },
  });

  // ── Footer ─────────────────────────────────────────────────────────────────

  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setFooter((tui, theme, footerData) => {
      // Expose this session's repaint trigger to the command above.
      requestRender = () => tui.requestRender();

      const root = new StatuslineRoot(theme);
      let lastBranch = footerData.getGitBranch();
      const sessionCwd = ctx.sessionManager.getCwd();

      if (lastBranch) {
        void prCache.fetch(lastBranch, sessionCwd, () => tui.requestRender());
      }

      const unsubscribePoll = subscribeAnthropicStatus(status => {
        anthropicStatus = status;
        tui.requestRender();
      });

      // Load config and conditionally start the usage-quota poller.
      void loadConfig().then(cfg => {
        if (cfg.anthropicUsage !== false && !usageUnsubscribe) {
          usageUnsubscribe = subscribeUsageQuota(({ quota, lastUpdated, error }) => {
            usageQuota = quota;
            usageLastUpdated = lastUpdated;
            usageError = error;
            tui.requestRender();
          });
        }
      });

      const unsubscribeBranch = footerData.onBranchChange(() => {
        const branch = footerData.getGitBranch();
        if (branch && branch !== lastBranch) {
          lastBranch = branch;
          void prCache.fetch(branch, ctx.sessionManager.getCwd(), () => tui.requestRender());
        }
        tui.requestRender();
      });

      // Periodic repaint. The host only repaints the footer on its own events
      // (token streaming, branch changes, our poll callbacks). Without a tick,
      // the relative "last updated" age (e.g. "3m") freezes on screen between
      // events even though wall-clock keeps moving, and extension statuses
      // (LSP/MCP) — which have no change subscription — can lag. 30s keeps the
      // minute-granularity age honest. Re-render is cheap: unchanged lines are
      // served from Text's per-line cache.
      const refreshTimer = setInterval(() => tui.requestRender(), 30_000);
      refreshTimer.unref?.();

      return {
        dispose: () => {
          unsubscribeBranch();
          unsubscribePoll();
          usageUnsubscribe?.();
          usageUnsubscribe = null;
          clearInterval(refreshTimer);
        },
        invalidate() {
          root.invalidate();
        },
        render(width: number): string[] {
          let inputTok = 0, outputTok = 0, cacheTok = 0, totalCost = 0;
          for (const e of ctx.sessionManager.getBranch()) {
            if (e.type === "message" && e.message.role === "assistant") {
              const m = e.message as AssistantMessage;
              inputTok += m.usage.input;
              outputTok += m.usage.output;
              cacheTok += m.usage.cacheRead;
              totalCost += m.usage.cost.total;
            }
          }

          const usage = ctx.getContextUsage();
          const branch = footerData.getGitBranch();
          // Status strings published by other extensions (LSP, MCP, …) via
          // ctx.ui.setStatus(). The default footer renders these; since we
          // replaced it, we pull them back in here.
          const extensionStatuses = [...footerData.getExtensionStatuses().values()];

          root.setData({
            inputTok,
            outputTok,
            cacheTok,
            totalCost,
            ctxPctNum: usage?.percent ?? null,
            ctxWindow: ctx.model?.contextWindow,
            modelId: ctx.model?.id.replace("claude-", "") ?? null,
            thinking: pi.getThinkingLevel(),
            sessionCwd: ctx.sessionManager.getCwd(),
            branch: branch ?? null,
            pr: branch ? prCache.get(branch) : undefined,
            webSearch,
            extensionStatuses,
            // mockStatus takes precedence over the live polled value.
            anthropic: mockStatus ?? anthropicStatus,
            usageQuota,
            usageEnabled: usageUnsubscribe !== null,
            usageLastUpdated,
            usageError,
          });

          return root.render(width);
        },
      };
    });
  });
}
