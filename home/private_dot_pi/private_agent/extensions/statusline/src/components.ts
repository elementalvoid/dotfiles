/**
 * pi-tui-backed statusline components.
 *
 * Why components instead of a pure render function:
 *   - Per-line caching: pi-tui's `Text` caches its render output by
 *     (text, width). With our render running on every `tui.requestRender()`
 *     call (token streaming, tool events, branch changes, poll ticks…),
 *     unchanged lines no longer pay the styling cost.
 *   - Background-painted outage banner: `Box` with a `toolErrorBg` bg fn
 *     paints the whole line — a real visual upgrade over coloring just the
 *     glyphs.
 *   - Theme correctness: each component stores its raw inputs and rebuilds
 *     pre-styled strings inside `invalidate()`. When the TUI signals a theme
 *     change via `invalidate()`, the rebuild picks up the new colors.
 *
 * pi-tui's containers stack vertically. Horizontal 3-column composition is
 * still done by `compose.ts` — that's fundamental to the layout and not
 * something the toolkit provides.
 */

import { Box, Container, Text } from "@earendil-works/pi-tui";

import {
  composeLeftCenterRight,
  composeLeftRight,
  composeCentered,
  visibleWidth,
} from "./compose.ts";
import {
  fmtDateTime,
  fmtTokens,
  hyperlink,
  sanitizeText,
  sanitizeUrl,
  shortenCwd,
  type ShortenedPath,
} from "./format.ts";
import type { AnthropicStatus } from "./anthropic-status.ts";
import type { UsageQuota } from "./usage-quota.ts";
import { fmtQuotaAge, formatUsageQuota } from "./usage-quota.ts";
import { UPDOG_PAGE } from "./anthropic-status.ts";
import type { PrInfo } from "./pr-cache.ts";

// ── Theme shape ──────────────────────────────────────────────────────────────

export interface RenderTheme {
  fg(slot: string, text: string): string;
  bg(slot: string, text: string): string;
}

export interface WebSearchState {
  enabled: boolean;
  model: string;
  thinking: string;
  location: { type: string; country?: string } | null;
}

// ── Internal data shapes ─────────────────────────────────────────────────────

interface StatsLineData {
  inputTok: number;
  outputTok: number;
  cacheTok: number;
  totalCost: number;
  ctxPctNum: number | null;
  ctxWindow: number | undefined;
  modelId: string | null;
  thinking: string;
  anthropic: AnthropicStatus;
  usageQuota: UsageQuota | null;
}

interface CwdLineData {
  sessionCwd: string;
  branch: string | null;
  pr: PrInfo | null | undefined;
  webSearch: WebSearchState | null;
  /** Pre-styled status strings from other extensions (LSP, MCP, …). */
  extensionStatuses: string[];
}

interface BannerData {
  title: string;
  outageStart: number | undefined;
}

// ── Helpers shared with the line builders ────────────────────────────────────

function ctxPctLabel(pct: number | null): { label: string; slot: string } {
  if (pct == null) return { label: "?%", slot: "accent" };
  const label = `${pct.toFixed(1)}%`;
  const slot = pct >= 60 ? "error" : pct >= 40 ? "warning" : "accent";
  return { label, slot };
}

function ctxSizeLabel(ctxWindow: number | undefined): string {
  if (!ctxWindow) return "?";
  if (ctxWindow >= 1_000_000) return `${(ctxWindow / 1_000_000).toFixed(1)}M`;
  return `${Math.round(ctxWindow / 1000)}k`;
}

function statusDotFor(status: AnthropicStatus): { dot: string; slot: string } {
  if (status.stale) return { dot: "\u25CB", slot: "muted" };       // ○
  switch (status.level) {
    case "outage":    return { dot: "\u2716", slot: "error" };     // ✖
    case "degraded":  return { dot: "\u25B2", slot: "warning" };   // ▲
    case "unknown":   return { dot: "\u25CB", slot: "muted" };     // ○
    case "operational":
    default:          return { dot: "\u25CF", slot: "success" };   // ●
  }
}

function renderCwd(short: ShortenedPath, theme: RenderTheme): string {
  let out = short.prefix ? theme.fg("accent", short.prefix) : "";
  short.parts.forEach((part, i) => {
    if (i > 0 || short.prefix) out += theme.fg("dim", "/");
    out += part.truncated ? theme.fg("dim", part.text) : theme.fg("accent", part.text);
  });
  return out;
}

// ── StatsLine: token stats │ Anthropic status │ model ───────────────────────

export class StatsLine extends Container {
  private data: StatsLineData | null = null;
  private readonly line = new Text("", 0, 0);
  private readonly theme: RenderTheme;

  constructor(theme: RenderTheme) {
    super();
    this.theme = theme;
    this.addChild(this.line);
  }

  setData(data: StatsLineData): void {
    this.data = data;
    this.rebuild();
  }

  override invalidate(): void {
    super.invalidate();
    this.rebuild();
  }

  /**
   * StatsLine renders one styled string sized to the latest known width.
   * The width parameter only matters for the horizontal composition, so we
   * defer the heavy work until `render(width)` is actually called.
   */
  override render(width: number): string[] {
    if (this.data) this.line.setText(this.compose(width));
    return super.render(width);
  }

  private rebuild(): void {
    // Caching: invalidate Text's cache so the next render(width) recomputes.
    this.line.setText("");
  }

  private compose(width: number): string {
    const d = this.data!;
    const theme = this.theme;
    const { label: ctxPct, slot: ctxSlot } = ctxPctLabel(d.ctxPctNum);
    const ctxSize = ctxSizeLabel(d.ctxWindow);
    const { dot: statusDot, slot: statusSlot } = statusDotFor(d.anthropic);
    const modelId = d.modelId ?? "no-model";

    // --/-- when the poller is active but no data yet (startup or error).
    const quotaLabel = d.usageEnabled
      ? (formatUsageQuota(d.usageQuota) ?? "--/--")
      : null;
    const ageLabel = d.usageEnabled && d.usageLastUpdated !== null
      ? fmtQuotaAge(d.usageLastUpdated)
      : null;

    const leftPlain =
      ` \u2191${fmtTokens(d.inputTok)} \u2193${fmtTokens(d.outputTok)} ` +
      `\uDB85\uDC0B${fmtTokens(d.cacheTok)} ${ctxPct}/${ctxSize} ` +
      `$${d.totalCost.toFixed(3)}`;
    const centerPlain =
      ` ${statusDot} Anthropic` +
      (quotaLabel ? `  ${quotaLabel}` : "") +
      (ageLabel ? ` \u00b7 ${ageLabel}` : "") +
      ` `;
    const rightPlain = `\uDB85\uDE7A ${modelId} (${d.thinking}) `;

    const leftStyled =
      " " + theme.fg("mdListBullet", "\u2191") + theme.fg("accent", fmtTokens(d.inputTok)) +
      " " + theme.fg("warning", "\u2193") + theme.fg("accent", fmtTokens(d.outputTok)) +
      " " + theme.fg("mdListBullet", "\uDB85\uDC0B") + theme.fg("accent", fmtTokens(d.cacheTok)) +
      " " + theme.fg(ctxSlot, ctxPct) + theme.fg("dim", "/") + theme.fg("accent", ctxSize) +
      " " + theme.fg("warning", `$${d.totalCost.toFixed(3)}`);

    const centerInner = theme.fg(statusSlot, statusDot) + theme.fg(statusSlot, " Anthropic");
    const centerUrl = sanitizeUrl(d.anthropic.incidentUrl ?? UPDOG_PAGE);
    const centerStyled =
      " " + hyperlink(centerUrl, centerInner) +
      (quotaLabel ? "  " + theme.fg("warning", quotaLabel) : "") +
      (ageLabel ? theme.fg("dim", ` \u00b7 ${ageLabel}`) : "") +
      " ";

    const rightStyled =
      theme.fg("accent", "\uDB85\uDE7A ") + theme.fg("text", modelId) +
      theme.fg("dim", " (") + theme.fg("accent", d.thinking) + theme.fg("dim", ")") + " ";

    return composeLeftCenterRight(
      leftStyled,  visibleWidth(leftPlain),
      centerStyled, visibleWidth(centerPlain),
      rightStyled, visibleWidth(rightPlain),
      width,
    );
  }
}

// ── OutageBanner: a Box with `toolErrorBg`, only present when active ────────

export class OutageBanner extends Box {
  private data: BannerData | null = null;
  private readonly line = new Text("", 0, 0);
  private readonly theme: RenderTheme;

  constructor(theme: RenderTheme) {
    // paddingX=0 paddingY=0 → no extra empty rows. bgFn paints the whole line.
    super(0, 0, s => theme.bg("toolErrorBg", s));
    this.theme = theme;
    this.addChild(this.line);
  }

  setData(data: BannerData): void {
    this.data = data;
    this.rebuild();
  }

  override invalidate(): void {
    super.invalidate();
    this.rebuild();
  }

  override render(width: number): string[] {
    if (this.data) this.line.setText(this.compose(width));
    return super.render(width);
  }

  private rebuild(): void {
    this.line.setText("");
  }

  private compose(width: number): string {
    const { title, outageStart } = this.data!;
    const safeTitle = sanitizeText(title);
    const timeSuffix = outageStart ? `  since ${fmtDateTime(outageStart)}` : "";
    const plain = `\u2716 ${safeTitle}${timeSuffix}`;
    // foreground colors are still applied; the bg fn paints any uncolored
    // padding area so the whole row reads as a banner.
    const styled =
      this.theme.fg("error", `\u2716 ${safeTitle}`) +
      this.theme.fg("muted", timeSuffix);
    return composeCentered(styled, visibleWidth(plain), width);
  }
}

// ── CwdLine: cwd / branch / PR │ web-search ─────────────────────────────────

export class CwdLine extends Container {
  private data: CwdLineData | null = null;
  private readonly line = new Text("", 0, 0);
  private readonly theme: RenderTheme;

  constructor(theme: RenderTheme) {
    super();
    this.theme = theme;
    this.addChild(this.line);
  }

  setData(data: CwdLineData): void {
    this.data = data;
    this.rebuild();
  }

  override invalidate(): void {
    super.invalidate();
    this.rebuild();
  }

  override render(width: number): string[] {
    if (this.data) this.line.setText(this.compose(width));
    return super.render(width);
  }

  private rebuild(): void {
    this.line.setText("");
  }

  private compose(width: number): string {
    const d = this.data!;
    const theme = this.theme;
    const short = shortenCwd(d.sessionCwd, 60);
    const cwdStyled = renderCwd(short, theme);
    const ws = d.webSearch?.enabled ? d.webSearch : null;
    const wsModel = ws?.model?.replace("claude-", "") ?? "";
    const wsLocation = ws?.location?.country ?? "";
    const safeBranch = d.branch ? sanitizeText(d.branch) : null;
    const prLabel = d.pr ? `PR #${d.pr.number}` : "";

    const leftPlain = ` ${short.plain}` +
      (safeBranch ? ` \u2387 ${safeBranch}` : "") +
      (prLabel ? ` ${prLabel}` : "");

    const leftStyled =
      " " + cwdStyled +
      (safeBranch ? theme.fg("toolDiffAdded", " \u2387 ") + theme.fg("accent", safeBranch) : "") +
      (d.pr
        ? " " + hyperlink(sanitizeUrl(d.pr.url), theme.fg("toolDiffAdded", prLabel))
        : "");

    // Center: pre-styled extension statuses (LSP, MCP, …).
    const statuses = d.extensionStatuses.filter(Boolean);
    const centerStyled = statuses.length ? statuses.join("  ") : "";
    const centerWidth = visibleWidth(centerStyled);

    // Right: web-search widget.
    const rightStyled = ws
      ? theme.fg("accent", "\uF002") + " " + theme.fg("text", wsModel) +
        theme.fg("dim", " (") + theme.fg("accent", ws.thinking) + theme.fg("dim", ")") +
        (wsLocation ? theme.fg("dim", " \u00B7") + theme.fg("accent", wsLocation) : "") + " "
      : " ";
    const rightWidth = visibleWidth(rightStyled);

    return composeLeftCenterRight(
      leftStyled,   visibleWidth(leftPlain),
      centerStyled, centerWidth,
      rightStyled,  rightWidth,
      width,
    );
  }
}

// ── Root: stats / [banner] / cwd ────────────────────────────────────────────

export interface StatuslineInputs {
  // Stats line
  inputTok: number;
  outputTok: number;
  cacheTok: number;
  totalCost: number;
  ctxPctNum: number | null;
  ctxWindow: number | undefined;
  modelId: string | null;
  thinking: string;
  // Cwd line
  sessionCwd: string;
  branch: string | null;
  pr: PrInfo | null | undefined;
  webSearch: WebSearchState | null;
  /** Pre-styled status strings published by other extensions (LSP, MCP, …). */
  extensionStatuses?: string[];
  // Anthropic status (drives both the dot on stats and the optional banner)
  anthropic: AnthropicStatus;
  // Usage quota from /api/oauth/usage
  usageQuota?: UsageQuota | null;
  /** true when the usage poller is active (shows --/-- on error/startup). */
  usageEnabled?: boolean;
  /** ms timestamp of last successful fetch; drives the · just now / · Xm age label. */
  usageLastUpdated?: number | null;
}

export class StatuslineRoot extends Container {
  private readonly stats: StatsLine;
  private readonly banner: OutageBanner;
  private readonly cwd: CwdLine;
  private bannerActive = false;

  constructor(theme: RenderTheme) {
    super();
    this.stats = new StatsLine(theme);
    this.banner = new OutageBanner(theme);
    this.cwd = new CwdLine(theme);
    this.addChild(this.stats);
    this.addChild(this.cwd);
  }

  /**
   * Update the entire footer state. Cheap when nothing changed because each
   * child line is cached by `Text` until either its data is overwritten or
   * `invalidate()` is called.
   */
  setData(inputs: StatuslineInputs): void {
    this.stats.setData({
      inputTok: inputs.inputTok,
      outputTok: inputs.outputTok,
      cacheTok: inputs.cacheTok,
      totalCost: inputs.totalCost,
      ctxPctNum: inputs.ctxPctNum,
      ctxWindow: inputs.ctxWindow,
      modelId: inputs.modelId,
      thinking: inputs.thinking,
      anthropic: inputs.anthropic,
      usageQuota: inputs.usageQuota ?? null,
      usageEnabled: inputs.usageEnabled ?? false,
      usageLastUpdated: inputs.usageLastUpdated ?? null,
    });
    this.cwd.setData({
      sessionCwd: inputs.sessionCwd,
      branch: inputs.branch,
      pr: inputs.pr,
      webSearch: inputs.webSearch,
      extensionStatuses: inputs.extensionStatuses ?? [],
    });

    const showBanner =
      inputs.anthropic.level === "outage" &&
      !inputs.anthropic.stale &&
      typeof inputs.anthropic.title === "string" &&
      inputs.anthropic.title.length > 0;

    if (showBanner) {
      this.banner.setData({
        title: inputs.anthropic.title!,
        outageStart: inputs.anthropic.outageStart,
      });
      if (!this.bannerActive) {
        // Keep order: stats, banner, cwd.
        this.children = [this.stats, this.banner, this.cwd];
        this.bannerActive = true;
      }
    } else if (this.bannerActive) {
      this.children = [this.stats, this.cwd];
      this.bannerActive = false;
    }
  }
}
