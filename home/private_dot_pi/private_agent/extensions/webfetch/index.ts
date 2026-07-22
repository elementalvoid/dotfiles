/**
 * webfetch extension
 *
 * Fetches a URL, extracts the main article content using Mozilla Readability
 * (the same engine as Firefox Reader Mode), and converts it to clean Markdown
 * using Turndown + GFM plugin.
 *
 * No system dependencies required. All packages are bundled in node_modules.
 *
 * Usage:
 *   - LLM tool: webfetch({ url: "https://..." })
 *   - Command:  /webfetch https://...
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { Text, Container, Markdown } from "@earendil-works/pi-tui";
import { keyHint, getMarkdownTheme, DynamicBorder } from "@earendil-works/pi-coding-agent";
import { Readability } from "@mozilla/readability";
import { parseHTML } from "linkedom";
import TurndownService from "turndown";
import { gfm } from "turndown-plugin-gfm";
import * as http from "node:http";
import * as https from "node:https";
import { URL } from "node:url";

// ---------------------------------------------------------------------------
// HTTP fetch (Node built-ins only, follows redirects, abort-aware)
// ---------------------------------------------------------------------------

interface FetchResult {
  body: string;
  finalUrl: string;
  contentType: string;
  status: number;
}

function fetchUrl(rawUrl: string, signal?: AbortSignal, maxRedirects = 10): Promise<FetchResult> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new DOMException("Aborted", "AbortError"));
      return;
    }

    const onAbort = () => reject(new DOMException("Aborted", "AbortError"));
    signal?.addEventListener("abort", onAbort, { once: true });

    function doRequest(url: string, redirectsLeft: number) {
      let parsed: URL;
      try {
        parsed = new URL(url);
      } catch {
        reject(new Error(`Invalid URL: ${url}`));
        return;
      }

      const lib = parsed.protocol === "https:" ? https : http;

      const req = lib.get(
        url,
        {
          headers: {
            "User-Agent":
              "Mozilla/5.0 (compatible; pi-webfetch/1.0; +https://github.com/earendil-works/pi)",
            Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
          },
        },
        (res) => {
          // Follow redirects
          if (
            res.statusCode &&
            res.statusCode >= 300 &&
            res.statusCode < 400 &&
            res.headers.location
          ) {
            res.resume(); // drain
            if (redirectsLeft <= 0) {
              reject(new Error("Too many redirects"));
              return;
            }
            const next = new URL(res.headers.location, url).toString();
            doRequest(next, redirectsLeft - 1);
            return;
          }

          const chunks: Buffer[] = [];
          res.on("data", (chunk: Buffer) => chunks.push(chunk));
          res.on("end", () => {
            signal?.removeEventListener("abort", onAbort);
            resolve({
              body: Buffer.concat(chunks).toString("utf-8"),
              finalUrl: url,
              contentType: res.headers["content-type"] ?? "",
              status: res.statusCode ?? 0,
            });
          });
          res.on("error", reject);
        },
      );

      req.on("error", reject);

      if (signal) {
        signal.addEventListener(
          "abort",
          () => {
            req.destroy();
            reject(new DOMException("Aborted", "AbortError"));
          },
          { once: true },
        );
      }
    }

    doRequest(rawUrl, maxRedirects);
  });
}

// ---------------------------------------------------------------------------
// Markdown-first site adapters
//
// Some sites serve JS-rendered SPA shells at their canonical HTML URLs but also
// publish a clean Markdown twin of every page. For these, we fetch the Markdown
// directly and SKIP Readability entirely.
//
// To add a new site: append an entry below. `match` decides if the adapter
// applies to a given URL; `toMarkdownUrl` returns the Markdown URL to fetch.
// ---------------------------------------------------------------------------

interface SiteAdapter {
  name: string;
  match: (url: URL) => boolean;
  toMarkdownUrl: (url: URL) => string;
}

const MD_FIRST_SITES: SiteAdapter[] = [
  {
    // AWS docs publish a `.md` twin for every `.html` page.
    name: "docs.aws.amazon.com",
    match: (url) => url.hostname === "docs.aws.amazon.com" && url.pathname.endsWith(".html"),
    toMarkdownUrl: (url) => {
      const u = new URL(url.toString());
      u.pathname = u.pathname.replace(/\.html$/, ".md");
      u.search = "";
      u.hash = "";
      return u.toString();
    },
  },
];

function findMdAdapter(rawUrl: string): SiteAdapter | null {
  let parsed: URL;
  try {
    parsed = new URL(rawUrl);
  } catch {
    return null;
  }
  return MD_FIRST_SITES.find((a) => a.match(parsed)) ?? null;
}

// A response "looks like Markdown" if it isn't an HTML document. AWS returns a
// 200 HTML error page for missing `.md` files, so guard on both status + shape.
function looksLikeHtml(body: string): boolean {
  const head = body.trimStart().slice(0, 200).toLowerCase();
  return head.startsWith("<!doctype") || head.startsWith("<html") || head.includes("<html");
}

// ---------------------------------------------------------------------------
// JS-redirect / SPA stub detection
//
// Tiny HTML bodies that only contain a meta-refresh or location.replace are
// redirect shells with no real content. We do NOT follow these blindly — we
// surface the detected target and let the caller decide.
// ---------------------------------------------------------------------------

const STUB_MAX_BYTES = 3000;

function detectStubRedirect(body: string, baseUrl: string): string | null {
  if (body.length > STUB_MAX_BYTES) return null;

  let target: string | null = null;

  // <meta http-equiv="refresh" content="0;URL=foo.html">
  const metaMatch = body.match(
    /http-equiv=["']?refresh["']?[^>]*content=["'][^"']*url=([^"';]+)/i,
  );
  if (metaMatch) target = metaMatch[1].trim();

  // location.replace("foo.html") or self.location = "foo.html"
  if (!target) {
    const jsMatch = body.match(
      /location(?:\.href)?\s*(?:=|\.replace\s*\()\s*["']([^"']+)["']/i,
    );
    if (jsMatch) target = jsMatch[1].trim();
  }

  if (!target) return null;

  try {
    return new URL(target, baseUrl).toString();
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Turndown setup (HTML → Markdown)
// ---------------------------------------------------------------------------

function buildTurndown(): TurndownService {
  const td = new TurndownService({
    headingStyle: "atx",
    hr: "---",
    bulletListMarker: "-",
    codeBlockStyle: "fenced",
    fence: "```",
    emDelimiter: "_",
    strongDelimiter: "**",
    linkStyle: "inlined",
  });

  // GFM: tables, strikethrough, task lists
  td.use(gfm);

  // Remove stuff that clutters markdown output
  td.remove(["script", "style", "noscript", "iframe", "form", "button", "input", "select"]);

  // Collapse excessive blank lines
  td.addRule("collapseBlankLines", {
    filter: "p",
    replacement: (content) => {
      const trimmed = content.trim();
      return trimmed ? `\n\n${trimmed}\n\n` : "";
    },
  });

  return td;
}

// ---------------------------------------------------------------------------
// Core extraction
// ---------------------------------------------------------------------------

interface ExtractResult {
  title: string;
  byline: string | null;
  siteName: string | null;
  excerpt: string | null;
  markdown: string;
  url: string;
  wordCount: number;
}

function extractAndConvert(html: string, url: string, includeImages: boolean): ExtractResult {
  // linkedom gives us a DOM without native bindings
  const { document } = parseHTML(html);

  // Optionally strip images before readability (saves tokens)
  if (!includeImages) {
    const imgs = document.querySelectorAll("img, picture, figure > img");
    for (const el of Array.from(imgs)) {
      el.remove();
    }
  }

  const reader = new Readability(document as unknown as Document, {
    charThreshold: 100,
    keepClasses: false,
  });

  const article = reader.parse();
  if (!article) {
    throw new Error("Readability could not extract content from this page. It may require JS rendering or be behind a paywall.");
  }

  const td = buildTurndown();
  let markdown = td.turndown(article.content);

  // Clean up artifacts: 3+ consecutive blank lines → 2
  markdown = markdown.replace(/\n{3,}/g, "\n\n").trim();

  const wordCount = markdown.split(/\s+/).filter(Boolean).length;

  return {
    title: article.title ?? "",
    byline: article.byline ?? null,
    siteName: article.siteName ?? null,
    excerpt: article.excerpt ?? null,
    markdown,
    url,
    wordCount,
  };
}

function formatOutput(result: ExtractResult): string {
  const lines: string[] = [];

  lines.push(`# ${result.title}`);

  const meta: string[] = [];
  if (result.siteName) meta.push(`**Source:** ${result.siteName}`);
  if (result.byline) meta.push(`**Author:** ${result.byline}`);
  meta.push(`**URL:** ${result.url}`);
  meta.push(`**Words:** ~${result.wordCount.toLocaleString()}`);
  if (result.excerpt) meta.push(`\n> ${result.excerpt}`);

  lines.push(meta.join("  \n"));
  lines.push("---");
  lines.push(result.markdown);

  return lines.join("\n\n");
}

function formatRawMarkdown(
  url: string,
  adapterName: string,
  markdown: string,
): { output: string; wordCount: number } {
  const clean = markdown.replace(/\n{3,}/g, "\n\n").trim();
  const wordCount = clean.split(/\s+/).filter(Boolean).length;
  const output = [
    `**Source:** ${adapterName} (Markdown)  \n**URL:** ${url}  \n**Words:** ~${wordCount.toLocaleString()}`,
    "---",
    clean,
  ].join("\n\n");
  return { output, wordCount };
}

// ---------------------------------------------------------------------------
// Shared resolver: md-first adapter → stub detection → Readability extraction
// ---------------------------------------------------------------------------

type ResolveResult =
  | { kind: "markdown"; output: string; finalUrl: string; title?: string; wordCount?: number }
  | { kind: "nonhtml"; output: string; finalUrl: string; contentType: string }
  | { kind: "stub"; finalUrl: string; redirectTarget: string }
  | { kind: "article"; output: string; result: ExtractResult };

async function resolveContent(
  rawUrl: string,
  includeImages: boolean,
  signal: AbortSignal | undefined,
  onStage?: (stage: string) => void,
): Promise<ResolveResult> {
  const url = rawUrl.replace(/^@/, "");

  // 1. Markdown-first adapters: fetch the .md twin and skip Readability.
  const adapter = findMdAdapter(url);
  if (adapter) {
    const mdUrl = adapter.toMarkdownUrl(new URL(url));
    onStage?.(`Fetching Markdown from ${mdUrl}…`);
    try {
      const md = await fetchUrl(mdUrl, signal);
      if (md.status < 400 && md.body.trim() && !looksLikeHtml(md.body)) {
        const { output, wordCount } = formatRawMarkdown(mdUrl, adapter.name, md.body);
        return { kind: "markdown", output, finalUrl: mdUrl, wordCount };
      }
      // Otherwise fall through to normal fetch of the original URL.
    } catch {
      // Ignore and fall back to the normal path.
    }
  }

  // 2. Normal fetch of the original URL.
  onStage?.(`Fetching ${url}…`);
  const fetched = await fetchUrl(url, signal);

  if (fetched.status >= 400) {
    throw new Error(`HTTP ${fetched.status} from ${fetched.finalUrl}`);
  }

  const ct = fetched.contentType.toLowerCase();
  if (!ct.includes("html") && !ct.includes("xml") && ct !== "") {
    const preview = fetched.body.slice(0, 2000);
    return {
      kind: "nonhtml",
      finalUrl: fetched.finalUrl,
      contentType: fetched.contentType,
      output: `[Non-HTML content: ${fetched.contentType}]\n\n${preview}${
        fetched.body.length > 2000 ? "\n\n…(truncated)" : ""
      }`,
    };
  }

  // 3. Stub / SPA-shell detection — do not follow blindly.
  const redirectTarget = detectStubRedirect(fetched.body, fetched.finalUrl);
  if (redirectTarget && redirectTarget !== fetched.finalUrl) {
    return { kind: "stub", finalUrl: fetched.finalUrl, redirectTarget };
  }

  // 4. Readability extraction.
  onStage?.(`Extracting content from ${url}…`);
  const result = extractAndConvert(fetched.body, fetched.finalUrl, includeImages);
  return { kind: "article", output: formatOutput(result), result };
}

// ---------------------------------------------------------------------------
// Extension entry point
// ---------------------------------------------------------------------------

export default function webfetchExtension(pi: ExtensionAPI) {
  const PARAMS = Type.Object({
    url: Type.String({
      description: "The URL to fetch and extract readable content from.",
    }),
    include_images: Type.Optional(
      Type.Boolean({
        description:
          "Whether to include image references in the Markdown output. Defaults to false to save tokens.",
      }),
    ),
  });

  // ── Tool (LLM-callable) ──────────────────────────────────────────────────
  pi.registerTool({
    name: "webfetch",
    label: "Web Fetch",
    description:
      "Fetch a URL and return its main article content as clean Markdown, using Mozilla Readability for extraction (same as Firefox Reader Mode). Use this to read web pages, documentation, articles, and blog posts.",
    promptSnippet:
      "Fetch a URL and return its article content as clean Markdown (Mozilla Readability + Firefox Reader Mode quality)",
    promptGuidelines: [
      "Use webfetch instead of bash curl when you need to read web page content — it strips boilerplate and returns clean Markdown.",
      "Pass include_images: true only when the user explicitly needs images.",
      "Do NOT use webfetch for GitHub URLs (github.com, raw.githubusercontent.com, gist.github.com). Use the gh CLI instead: 'gh repo view OWNER/REPO' for repo overviews, 'gh issue view NUMBER --repo OWNER/REPO' for issues, 'gh pr view NUMBER --repo OWNER/REPO' for pull requests. For file contents, use 'gh api repos/OWNER/REPO/contents/PATH --jq .content | base64 -d' for a single file — but if you need to read more than one or two files from a repo, clone it first with 'gh repo clone OWNER/REPO' and then use the read tool to explore the files directly.",
    ],
    parameters: PARAMS,

    async execute(_toolCallId, params, signal, onUpdate, _ctx) {
      const url = params.url.replace(/^@/, ""); // handle accidental @ prefix
      const includeImages = params.include_images ?? false;

      let resolved: ResolveResult;
      try {
        resolved = await resolveContent(url, includeImages, signal ?? undefined, (stage) =>
          onUpdate?.({ content: [{ type: "text", text: stage }], details: { stage, url } }),
        );
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        throw new Error(`Failed to fetch ${url}: ${msg}`);
      }

      switch (resolved.kind) {
        case "markdown":
          return {
            content: [{ type: "text", text: resolved.output }],
            details: { url: resolved.finalUrl, source: "markdown", wordCount: resolved.wordCount },
          };

        case "nonhtml":
          return {
            content: [{ type: "text", text: resolved.output }],
            details: { url: resolved.finalUrl, contentType: resolved.contentType },
          };

        case "stub":
          return {
            content: [
              {
                type: "text",
                text:
                  `The page at ${resolved.finalUrl} is a redirect/SPA shell with no readable content. ` +
                  `It points to:\n\n  ${resolved.redirectTarget}\n\n` +
                  `This redirect was not followed automatically. If you want its content, ask the user ` +
                  `to confirm, then call webfetch again with that URL.`,
              },
            ],
            details: { url: resolved.finalUrl, redirectTarget: resolved.redirectTarget, stub: true },
          };

        case "article":
          return {
            content: [{ type: "text", text: resolved.output }],
            details: {
              url: resolved.result.url,
              title: resolved.result.title,
              byline: resolved.result.byline,
              siteName: resolved.result.siteName,
              wordCount: resolved.result.wordCount,
            },
          };
      }
    },

    // ── Custom rendering: compact summary by default, full content on expand ──
    renderResult(result, { expanded, isPartial }, theme, _context) {
      if (isPartial) {
        return new Text(theme.fg("warning", "Fetching…"), 0, 0);
      }

      const d = (result.details ?? {}) as {
        title?: string;
        url?: string;
        source?: string;
        wordCount?: number;
        contentType?: string;
        stub?: boolean;
        redirectTarget?: string;
      };
      const fullText = result.content?.map((c) => (c.type === "text" ? c.text : "")).join("") ?? "";

      // Stub redirect: warn and always show the target (short, no expand needed).
      if (d.stub) {
        return new Text(
          theme.fg("warning", "⚠ Redirect shell — not followed") +
            "\n  " +
            theme.fg("dim", `→ ${d.redirectTarget ?? "unknown"}`),
          0,
          0,
        );
      }

      // Build a one-line summary.
      const label = d.title || d.url || "content";
      const bits: string[] = [];
      if (typeof d.wordCount === "number") bits.push(`~${d.wordCount.toLocaleString()} words`);
      if (d.source === "markdown") bits.push("Markdown");
      else if (d.contentType) bits.push(d.contentType);
      const suffix = bits.length ? theme.fg("dim", ` (${bits.join(", ")})`) : "";
      const summary = theme.fg("success", "✓ ") + theme.fg("toolTitle", label) + suffix;

      if (!expanded) {
        return new Text(
          summary + theme.fg("dim", `  ${keyHint("app.tools.expand", "to expand")}`),
          0,
          0,
        );
      }

      // Expanded: frame the fetched content in an accent-bordered panel so it
      // reads as clearly distinct from normal agent output.
      const accent = (s: string) => theme.fg("accent", s);
      const container = new Container();
      container.addChild(new DynamicBorder(accent));
      container.addChild(
        new Text(summary + theme.fg("dim", `  ${keyHint("app.tools.expand", "to collapse")}`), 1, 0),
      );
      container.addChild(new DynamicBorder(accent));
      container.addChild(new Markdown(fullText, 1, 0, getMarkdownTheme()));
      container.addChild(new DynamicBorder(accent));
      return container;
    },
  });

  // ── Command (/webfetch <url>) ─────────────────────────────────────────────
  pi.registerCommand("webfetch", {
    description: "Fetch a URL and print its article content as Markdown. Usage: /webfetch <url>",
    handler: async (args, ctx) => {
      const url = args?.trim();
      if (!url) {
        ctx.ui.notify("Usage: /webfetch <url>", "warning");
        return;
      }

      ctx.ui.setStatus("webfetch", `Fetching ${url}…`);

      try {
        let resolved = await resolveContent(url, false, undefined, (stage) =>
          ctx.ui.setStatus("webfetch", stage),
        );

        // Stub redirect: ask the user before following (don't trust it blindly).
        if (resolved.kind === "stub") {
          ctx.ui.setStatus("webfetch", "");
          const follow = await ctx.ui.confirm(
            "Follow redirect?",
            `${resolved.finalUrl} is a redirect shell pointing to:\n\n${resolved.redirectTarget}\n\nFetch that URL instead?`,
          );
          if (!follow) {
            ctx.ui.notify("webfetch: redirect not followed.", "info");
            return;
          }
          ctx.ui.setStatus("webfetch", `Fetching ${resolved.redirectTarget}…`);
          resolved = await resolveContent(resolved.redirectTarget, false, undefined, (stage) =>
            ctx.ui.setStatus("webfetch", stage),
          );
        }

        if (resolved.kind === "stub") {
          ctx.ui.notify("webfetch: target is still a redirect shell.", "warning");
          return;
        }

        const output = resolved.output;
        pi.sendUserMessage(`Here is the fetched content from ${url}:\n\n${output}`, {
          deliverAs: "followUp",
        });

        const label =
          resolved.kind === "article"
            ? `"${resolved.result.title}" (~${resolved.result.wordCount.toLocaleString()} words)`
            : "content";
        ctx.ui.notify(`Fetched: ${label}`, "info");
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        ctx.ui.notify(`webfetch error: ${msg}`, "error");
      } finally {
        ctx.ui.setStatus("webfetch", "");
      }
    },
  });
}
