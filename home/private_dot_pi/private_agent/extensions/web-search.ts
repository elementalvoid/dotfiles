import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import type { AutocompleteItem } from "@earendil-works/pi-tui";

/**
 * Anthropic Web Search Extension
 *
 * User settings are persisted to ~/.pi/agent/web-search-settings.json.
 * Edit that file directly for advanced config (domains, full location, etc).
 *
 * Commands:
 *   /websearch                        — show current settings
 *   /websearch on | off               — toggle for this session
 *   /websearch model <model>          — set search model (persisted)
 *   /websearch thinking <level>       — set thinking effort (persisted)
 *   /websearch location off           — disable location (persisted)
 *   /websearch location <country>     — set country code, e.g. US, GB (persisted)
 */

// ── Types ─────────────────────────────────────────────────────────────────────

type ThinkingEffort = "off" | "low" | "medium" | "high";

interface WebSearchSettings {
  model: string;
  thinking: ThinkingEffort;
  maxUses: number;
  allowedDomains: string[];
  blockedDomains: string[];
  location: {
    type: "approximate";
    city?: string;
    region?: string;
    country?: string;   // ISO 3166-1 alpha-2, e.g. "US", "GB"
    timezone?: string;  // IANA tz, e.g. "America/Chicago"
  } | null;
}

export interface WebSearchState {
  enabled: boolean;
  model: string;
  thinking: ThinkingEffort;
  location: WebSearchSettings["location"];
}

// ── Defaults ──────────────────────────────────────────────────────────────────

const DEFAULT_SETTINGS: WebSearchSettings = {
  model: "claude-haiku-4-5",
  thinking: "low",
  maxUses: 5,
  allowedDomains: [],
  blockedDomains: [],
  location: null,
};

const KNOWN_MODELS = ["claude-haiku-4-5", "claude-sonnet-4-6", "claude-opus-4-6"] as const;
const THINKING_LEVELS: ThinkingEffort[] = ["off", "low", "medium", "high"];

// Models supporting web_search_20260209 (dynamic filtering)
const DYNAMIC_SEARCH_MODELS = ["claude-sonnet-4-6", "claude-opus-4-6", "claude-mythos"];
// Models supporting adaptive thinking
const THINKING_MODELS = ["claude-sonnet-4-6", "claude-opus-4-6", "claude-mythos"];

const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

const SETTINGS_PATH = join(process.env.HOME ?? "~", ".pi", "agent", "web-search-settings.json");

// ── Helpers ───────────────────────────────────────────────────────────────────

const searchToolType = (model: string) =>
  DYNAMIC_SEARCH_MODELS.some((m) => model.toLowerCase().includes(m))
    ? "web_search_20260209"
    : "web_search_20250305";

const supportsThinking = (model: string) =>
  THINKING_MODELS.some((m) => model.toLowerCase().includes(m));

function loadSettings(): WebSearchSettings {
  try {
    const raw = JSON.parse(readFileSync(SETTINGS_PATH, "utf8"));
    return { ...DEFAULT_SETTINGS, ...raw };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

function saveSettings(s: WebSearchSettings): void {
  try {
    mkdirSync(join(process.env.HOME ?? "~", ".pi", "agent"), { recursive: true });
    writeFileSync(SETTINGS_PATH, JSON.stringify(s, null, 2) + "\n", "utf8");
  } catch {}
}

// ── Extension ─────────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  let enabled = true;
  let settings = loadSettings();

  const emitState = () => {
    pi.events.emit("web-search:state", {
      enabled,
      model: settings.model,
      thinking: settings.thinking,
      location: settings.location,
    } satisfies WebSearchState);
  };

  const getAuth = (): { key: string; isOAuth: boolean } | undefined => {
    if (process.env.ANTHROPIC_API_KEY) {
      return { key: process.env.ANTHROPIC_API_KEY, isOAuth: false };
    }
    try {
      const authPath = join(process.env.HOME ?? "~", ".pi", "agent", "auth.json");
      const auth = JSON.parse(readFileSync(authPath, "utf8"));
      const token = auth?.anthropic?.access;
      if (token) return { key: token, isOAuth: true };
    } catch {}
    return undefined;
  };

  // ── Tool ────────────────────────────────────────────────────────────────────

  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description:
      "Search the web for current, real-time information beyond the model's knowledge cutoff. " +
      "Use for recent events, software releases, prices, news, or anything post-training. " +
      "Results include inline markdown citations and a Sources section with every URL referenced.",
    promptSnippet:
      "Search the web for real-time information beyond the knowledge cutoff. " +
      "Results include inline markdown citations linking to their sources.",
    parameters: Type.Object({
      query: Type.String({ description: "The search query" }),
      allowed_domains: Type.Optional(
        Type.Array(Type.String(), {
          description: 'Restrict to these domains only, e.g. ["github.com"]',
        })
      ),
      blocked_domains: Type.Optional(
        Type.Array(Type.String(), { description: "Exclude these domains from results" })
      ),
    }),

    async execute(_toolCallId, params, signal, onUpdate, _ctx) {
      if (!enabled) {
        return {
          content: [{ type: "text", text: "Web search is disabled. Use /websearch to enable it." }],
          details: {},
        };
      }

      const auth = getAuth();
      if (!auth) {
        return {
          content: [{ type: "text", text: "No Anthropic credentials found. Set ANTHROPIC_API_KEY or log in via pi." }],
          details: {},
          isError: true,
        };
      }

      const model = settings.model;
      const thinking =
        settings.thinking !== "off" && supportsThinking(model)
          ? { type: "adaptive", effort: settings.thinking }
          : undefined;

      onUpdate?.({ content: [{ type: "text", text: `Searching: ${params.query}…` }] });

      const searchTool: Record<string, unknown> = {
        type: searchToolType(model),
        name: "web_search",
        max_uses: settings.maxUses,
      };
      const effectiveAllowed = params.allowed_domains?.length ? params.allowed_domains : settings.allowedDomains;
      const effectiveBlocked = params.blocked_domains?.length ? params.blocked_domains : settings.blockedDomains;
      if (effectiveAllowed.length) searchTool.allowed_domains = effectiveAllowed;
      if (effectiveBlocked.length) searchTool.blocked_domains = effectiveBlocked;
      if (settings.location) searchTool.user_location = settings.location;

      const body: Record<string, unknown> = {
        model,
        max_tokens: 4096,
        messages: [{
          role: "user",
          content: (() => {
            const now = new Date();
            const currentDate = now.toISOString().split("T")[0];
            const currentYear = now.getFullYear();
            return (
              `Today's date is ${currentDate}. Prefer results from ${currentYear}` +
              ` (or late ${currentYear - 1} if nothing newer exists) to ensure the information is current.\n\n` +
              `Search the web for: "${params.query}"\n\n` +
              `Respond with a clear, well-structured markdown summary that directly answers the query. ` +
              `Use headers, bullet points, or numbered lists where they improve readability. ` +
              `**You MUST cite every factual claim with an inline markdown link to its source**, ` +
              `e.g. [Source Name](https://example.com). End your response with a ## Sources section ` +
              `listing every URL referenced.`
            );
          })(),
        }],
        tools: [searchTool],
      };
      if (thinking) body.thinking = thinking;

      const headers: Record<string, string> = {
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
      };
      if (auth.isOAuth) {
        headers["Authorization"] = `Bearer ${auth.key}`;
        headers["anthropic-beta"] = "claude-code-20250219,oauth-2025-04-20";
      } else {
        headers["x-api-key"] = auth.key;
      }

      let response: Response;
      try {
        response = await fetch(ANTHROPIC_API, {
          method: "POST",
          headers,
          body: JSON.stringify(body),
          signal: signal ?? undefined,
        });
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        return {
          content: [{ type: "text", text: `Network error: ${msg}` }],
          details: {},
          isError: true,
        };
      }

      if (!response.ok) {
        const errBody = await response.text();
        return {
          content: [{ type: "text", text: `Anthropic API error ${response.status}: ${errBody}` }],
          details: {},
          isError: true,
        };
      }

      const data = await response.json() as {
        content: Array<{ type: string; text?: string }>;
        stop_reason?: string;
      };

      const text = data.content
        .filter((b) => b.type === "text" && b.text)
        .map((b) => b.text!)
        .join("\n\n");

      return {
        content: [{ type: "text", text: text || "No results found." }],
        details: { query: params.query, model, toolType: searchToolType(model), thinking: thinking ?? null },
      };
    },
  });

  // ── /websearch command ───────────────────────────────────────────────────────

  pi.registerCommand("websearch", {
    description: "Web search settings — /websearch [on|off|model <m>|thinking <level>|location <country|off>]",

    getArgumentCompletions: (prefix: string): AutocompleteItem[] | null => {
      const parts = prefix.trimStart().split(/\s+/);
      const sub = parts[0] ?? "";
      const arg = parts[1] ?? "";

      if (parts.length <= 1) {
        return ["on", "off", "model", "thinking", "location"]
          .filter((s) => s.startsWith(sub))
          .map((s) => ({ value: s, label: s }));
      }
      if (sub === "model") {
        return [...KNOWN_MODELS]
          .filter((m) => m.includes(arg))
          .map((m) => ({ value: `model ${m}`, label: m }));
      }
      if (sub === "thinking") {
        return THINKING_LEVELS
          .filter((l) => l.startsWith(arg))
          .map((l) => ({ value: `thinking ${l}`, label: l }));
      }
      if (sub === "location") {
        return ["off"]
          .filter((l) => l.startsWith(arg))
          .map((l) => ({ value: `location ${l}`, label: l }));
      }
      return null;
    },

    handler: async (args, ctx) => {
      const parts = (args ?? "").trim().split(/\s+/).filter(Boolean);
      const sub = parts[0];
      const arg = parts[1];

      // ── status ──
      if (!sub) {
        const d = (key: keyof WebSearchSettings) =>
          JSON.stringify(settings[key]) === JSON.stringify(DEFAULT_SETTINGS[key])
            ? " (default)" : "";
        const locStr = settings.location ? JSON.stringify(settings.location) : "off";
        const thinkingNote =
          settings.thinking !== "off" && !supportsThinking(settings.model)
            ? ` ⚠ ${settings.model} doesn't support thinking`
            : "";
        ctx.ui.notify(
          [
            `Web search: ${enabled ? "on ✓" : "off (session)"}`,
            `Model:      ${settings.model}${d("model")}`,
            `Thinking:   ${settings.thinking}${thinkingNote}${d("thinking")}`,
            `Tool type:  ${searchToolType(settings.model)}`,
            `Max uses:   ${settings.maxUses}${d("maxUses")}`,
            ...(settings.allowedDomains.length ? [`Allow:      ${settings.allowedDomains.join(", ")}`] : []),
            ...(settings.blockedDomains.length ? [`Block:      ${settings.blockedDomains.join(", ")}`] : []),
            `Location:   ${locStr}${d("location")}`,
            ``,
            `Settings file: ${SETTINGS_PATH}`,
          ].join("\n"),
          "info"
        );
        return;
      }

      // ── on / off ──
      if (sub === "on" || sub === "off") {
        enabled = sub === "on";
        emitState();
        ctx.ui.notify(`Web search ${enabled ? "enabled ✓" : "disabled"}`, enabled ? "success" : "info");
        return;
      }

      // ── model ──
      if (sub === "model") {
        if (!arg) {
          ctx.ui.notify(`Current: ${settings.model}\nOptions: ${KNOWN_MODELS.join(", ")}`, "info");
          return;
        }
        settings = { ...settings, model: arg };
        saveSettings(settings);
        emitState();
        const modelDefault = arg === DEFAULT_SETTINGS.model ? " (default)" : "";
        ctx.ui.notify(`Search model → ${arg}${modelDefault}`, "success");
        return;
      }

      // ── thinking ──
      if (sub === "thinking") {
        if (!arg) {
          ctx.ui.notify(`Current: ${settings.thinking}\nOptions: ${THINKING_LEVELS.join(", ")}`, "info");
          return;
        }
        if (!THINKING_LEVELS.includes(arg as ThinkingEffort)) {
          ctx.ui.notify(`Unknown level "${arg}". Options: ${THINKING_LEVELS.join(", ")}`, "error");
          return;
        }
        settings = { ...settings, thinking: arg as ThinkingEffort };
        saveSettings(settings);
        emitState();
        if (arg !== "off" && !supportsThinking(settings.model)) {
          ctx.ui.notify(
            `Thinking set to "${arg}" but ${settings.model} doesn't support it.\nSwitch to sonnet-4-6 or opus-4-6 to use thinking.`,
            "warning"
          );
        } else {
          const thinkDefault = arg === DEFAULT_SETTINGS.thinking ? " (default)" : "";
          ctx.ui.notify(`Thinking effort → ${arg}${thinkDefault}`, "success");
        }
        return;
      }

      // ── location ──
      if (sub === "location") {
        if (!arg) {
          ctx.ui.notify(
            [
              `Current: ${settings.location ? JSON.stringify(settings.location) : "off"}`,
              ``,
              `Usage:`,
              `  /websearch location off         disable location`,
              `  /websearch location <country>   e.g. US, GB, DE, AU`,
              ``,
              `For city/region/timezone, edit the settings file directly:`,
              `  ${SETTINGS_PATH}`,
            ].join("\n"),
            "info"
          );
          return;
        }
        if (arg === "off") {
          settings = { ...settings, location: null };
          saveSettings(settings);
          emitState();
          const locDefault = DEFAULT_SETTINGS.location === null ? " (default)" : "";
          ctx.ui.notify(`Location disabled${locDefault}`, "success");
        } else {
          const country = arg.toUpperCase().slice(0, 2);
          settings = { ...settings, location: { type: "approximate", country } };
          saveSettings(settings);
          emitState();
          ctx.ui.notify(`Location → ${country}`, "success");
        }
        return;
      }

      ctx.ui.notify(
        `Unknown subcommand "${sub}".\nUsage: /websearch [on|off|model <m>|thinking <level>|location <country|off>]`,
        "error"
      );
    },
  });

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  pi.on("session_start", async (_event, _ctx) => {
    settings = loadSettings();
    emitState();
  });
}
