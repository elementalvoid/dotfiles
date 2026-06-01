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

      onUpdate?.({
        content: [{ type: "text", text: `Fetching ${url}…` }],
        details: { stage: "fetch", url },
      });

      let fetched: FetchResult;
      try {
        fetched = await fetchUrl(url, signal ?? undefined);
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        throw new Error(`Failed to fetch ${url}: ${msg}`);
      }

      if (fetched.status >= 400) {
        throw new Error(`HTTP ${fetched.status} from ${fetched.finalUrl}`);
      }

      const ct = fetched.contentType.toLowerCase();
      if (!ct.includes("html") && !ct.includes("xml") && ct !== "") {
        // Likely a PDF, image, etc. — return raw truncated text
        const preview = fetched.body.slice(0, 2000);
        return {
          content: [
            {
              type: "text",
              text: `[Non-HTML content: ${fetched.contentType}]\n\n${preview}${fetched.body.length > 2000 ? "\n\n…(truncated)" : ""}`,
            },
          ],
          details: { url: fetched.finalUrl, contentType: fetched.contentType },
        };
      }

      onUpdate?.({
        content: [{ type: "text", text: `Extracting content from ${url}…` }],
        details: { stage: "extract", url },
      });

      let result: ExtractResult;
      try {
        result = extractAndConvert(fetched.body, fetched.finalUrl, includeImages);
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        throw new Error(`Extraction failed for ${url}: ${msg}`);
      }

      const output = formatOutput(result);

      return {
        content: [{ type: "text", text: output }],
        details: {
          url: result.url,
          title: result.title,
          byline: result.byline,
          siteName: result.siteName,
          wordCount: result.wordCount,
        },
      };
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
        const fetched = await fetchUrl(url);

        if (fetched.status >= 400) {
          ctx.ui.notify(`HTTP ${fetched.status} from ${url}`, "error");
          ctx.ui.setStatus("webfetch", "");
          return;
        }

        ctx.ui.setStatus("webfetch", `Extracting content…`);

        const result = extractAndConvert(fetched.body, fetched.finalUrl, false);
        const output = formatOutput(result);

        // Inject as a user message so the LLM can see and work with the content
        pi.sendUserMessage(
          `Here is the fetched content from ${url}:\n\n${output}`,
          { deliverAs: "followUp" },
        );

        ctx.ui.notify(`Fetched: "${result.title}" (~${result.wordCount.toLocaleString()} words)`, "success");
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        ctx.ui.notify(`webfetch error: ${msg}`, "error");
      } finally {
        ctx.ui.setStatus("webfetch", "");
      }
    },
  });
}
