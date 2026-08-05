import { spawn } from "node:child_process";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { type Static, Type, type TSchema } from "typebox";

/**
 * Slack bridge extension.
 *
 * pi cannot connect directly to the claude.ai-managed Slack connector (it is
 * account-bound, not a standalone MCP endpoint). Instead we expose one thin pi
 * tool per Slack connector tool. Each tool shells out to `claude -p` and forces
 * claude to invoke exactly that one MCP tool with the exact arguments pi passed
 * — claude does no reasoning, no composition, no summarizing. pi's agent owns
 * all the thinking; claude is a dumb transport to the connector.
 *
 * The raw MCP tool result is extracted from claude's stream-json output by
 * matching the tool_use id, so the connector's verbatim response (not claude's
 * paraphrase) is returned to pi.
 *
 * Requires: `claude` on PATH and authenticated (interactive login done once).
 */

const prefix = (t: string) => `mcp__claude_ai_Slack__${t}`;

// ---------------------------------------------------------------------------
// Raw tool-call transport
// ---------------------------------------------------------------------------

/** Extract text from a tool_result `content` (array of blocks or a string). */
function extractResultText(content: unknown): string {
	if (typeof content === "string") return content;
	if (Array.isArray(content)) {
		return content
			.map((b) => (b && typeof b === "object" && "text" in b ? String((b as { text?: unknown }).text ?? "") : ""))
			.join("");
	}
	return "";
}

/**
 * Force claude to call exactly one Slack MCP tool with exact args and return the
 * raw MCP result. Matches by tool_use id to ignore Tool Search meta results.
 */
function runSlackTool(fullName: string, args: Record<string, unknown>, signal: AbortSignal): Promise<string> {
	return new Promise((resolve, reject) => {
		const prompt =
			`Call the tool ${fullName} with exactly these arguments as verbatim JSON, and do nothing ` +
			`else — no analysis, no summary, no additional tool calls:\n${JSON.stringify(args)}`;
		const cargs = [
			"-p",
			prompt,
			"--model",
			"sonnet",
			"--effort",
			"low",
			"--allowed-tools",
			fullName,
			"--output-format",
			"stream-json",
			"--verbose",
		];

		const child = spawn("claude", cargs, { signal });
		let out = "";
		let err = "";
		child.stdout.on("data", (d) => (out += d.toString()));
		child.stderr.on("data", (d) => (err += d.toString()));
		child.on("error", reject);
		child.on("close", (code) => {
			if (code !== 0) {
				reject(new Error(err.trim() || `claude exited with code ${code}`));
				return;
			}

			const toolUseIds = new Set<string>();
			const resultsById = new Map<string, { text: string; isError: boolean }>();
			let finalResult = "";

			for (const line of out.split("\n")) {
				const t = line.trim();
				if (!t) continue;
				let o: {
					type?: string;
					result?: unknown;
					message?: { content?: unknown };
				};
				try {
					o = JSON.parse(t);
				} catch {
					continue;
				}
				if (o.type === "result" && typeof o.result === "string") finalResult = o.result;
				const content = o.message?.content;
				if (Array.isArray(content)) {
					for (const b of content as Array<Record<string, unknown>>) {
						if (b.type === "tool_use" && b.name === fullName && typeof b.id === "string") {
							toolUseIds.add(b.id);
						}
						if (b.type === "tool_result" && typeof b.tool_use_id === "string") {
							resultsById.set(b.tool_use_id, {
								text: extractResultText(b.content),
								isError: b.is_error === true,
							});
						}
					}
				}
			}

			for (const id of toolUseIds) {
				const r = resultsById.get(id);
				if (r) {
					if (r.isError) reject(new Error(r.text || "Slack tool returned an error"));
					else resolve(r.text);
					return;
				}
			}
			// The tool never ran (e.g. permission prompt / refusal). Surface claude's
			// final message so the failure is visible rather than silently empty.
			reject(new Error(finalResult || "Slack tool did not run (no result captured)."));
		});
	});
}

// ---------------------------------------------------------------------------
// Tool definitions (1:1 with the Slack connector tools)
// ---------------------------------------------------------------------------

const opt = Type.Optional;
const S = Type.String;
const I = Type.Integer;
const B = Type.Boolean;

interface SlackToolDef {
	name: string;
	label: string;
	description: string;
	snippet: string;
	parameters: TSchema;
	/** Writes/sends. Gated behind user confirmation unless skip_approval is set. */
	destructive?: boolean;
}

// Optional approval-bypass flag added to destructive tool schemas.
const skipApproval = opt(
	B({
		description:
			"Set true ONLY when the user explicitly waived approval (e.g. 'no approval needed'). " +
			"Otherwise omit so the user must confirm before this write/send executes.",
	}),
);

const RESP_FMT = opt(S({ description: "Response format, e.g. 'markdown' or 'plain' (optional)." }));

const TOOL_DEFS: SlackToolDef[] = [
	{
		name: "slack_search_public",
		label: "Slack search",
		description: "Search public Slack messages/content. Returns raw connector results with permalinks.",
		snippet: "Search public Slack messages",
		parameters: Type.Object({
			query: S({ description: "Search query (Slack search syntax supported)." }),
			after: opt(S({ description: "Only messages after this date (YYYY-MM-DD)." })),
			before: opt(S({ description: "Only messages before this date (YYYY-MM-DD)." })),
			content_types: opt(S()),
			context_channel_id: opt(S()),
			cursor: opt(S({ description: "Pagination cursor from a previous response." })),
			include_bots: opt(B()),
			include_context: opt(B()),
			limit: opt(I({ description: "Max results." })),
			max_context_length: opt(I()),
			response_format: RESP_FMT,
			sort: opt(S()),
			sort_dir: opt(S()),
		}),
	},
	{
		name: "slack_search_public_and_private",
		label: "Slack search (all)",
		description:
			"Search public AND private Slack messages the user can access. Returns raw connector results.",
		snippet: "Search public + private Slack messages",
		parameters: Type.Object({
			query: S({ description: "Search query (Slack search syntax supported)." }),
			after: opt(S({ description: "Only messages after this date (YYYY-MM-DD)." })),
			before: opt(S({ description: "Only messages before this date (YYYY-MM-DD)." })),
			channel_types: opt(S()),
			content_types: opt(S()),
			context_channel_id: opt(S()),
			cursor: opt(S()),
			include_bots: opt(B()),
			include_context: opt(B()),
			limit: opt(I()),
			max_context_length: opt(I()),
			response_format: RESP_FMT,
			sort: opt(S()),
			sort_dir: opt(S()),
		}),
	},
	{
		name: "slack_search_channels",
		label: "Slack channel search",
		description: "Search for Slack channels by name/topic.",
		snippet: "Find Slack channels",
		parameters: Type.Object({
			query: S({ description: "Channel search query." }),
			channel_types: opt(S({ description: "Filter, e.g. 'public_channel,private_channel'." })),
			cursor: opt(S()),
			include_archived: opt(B()),
			limit: opt(I()),
			response_format: RESP_FMT,
		}),
	},
	{
		name: "slack_search_users",
		label: "Slack user search",
		description: "Search Slack users by name/handle/email. Returns user IDs and profile info.",
		snippet: "Find Slack users",
		parameters: Type.Object({
			query: S({ description: "User search query (name, handle, or email)." }),
			cursor: opt(S()),
			limit: opt(I()),
			response_format: RESP_FMT,
		}),
	},
	{
		name: "slack_read_channel",
		label: "Slack read channel",
		description: "Read recent messages from a Slack channel by channel_id.",
		snippet: "Read a Slack channel's messages",
		parameters: Type.Object({
			channel_id: S({ description: "Slack channel ID (e.g. C0123ABCD)." }),
			cursor: opt(S()),
			latest: opt(S({ description: "End of time range (Slack ts)." })),
			oldest: opt(S({ description: "Start of time range (Slack ts)." })),
			limit: opt(I()),
			response_format: RESP_FMT,
		}),
	},
	{
		name: "slack_read_thread",
		label: "Slack read thread",
		description: "Read a Slack thread's replies by channel_id + message_ts.",
		snippet: "Read a Slack thread",
		parameters: Type.Object({
			channel_id: S({ description: "Slack channel ID." }),
			message_ts: S({ description: "Timestamp (ts) of the thread's root message." }),
			cursor: opt(S()),
			latest: opt(S()),
			oldest: opt(S()),
			limit: opt(I()),
			response_format: RESP_FMT,
		}),
	},
	{
		name: "slack_read_user_profile",
		label: "Slack read profile",
		description: "Read a Slack user's profile by user_id.",
		snippet: "Read a Slack user profile",
		parameters: Type.Object({
			user_id: opt(S({ description: "Slack user ID (e.g. U0123ABCD). Defaults to the current user." })),
			include_locale: opt(B()),
			response_format: RESP_FMT,
		}),
	},
	{
		name: "slack_read_canvas",
		label: "Slack read canvas",
		description: "Read a Slack canvas by canvas_id.",
		snippet: "Read a Slack canvas",
		parameters: Type.Object({
			canvas_id: S({ description: "Slack canvas ID." }),
		}),
	},
	{
		name: "slack_send_message_draft",
		label: "Slack draft",
		description:
			"Create an UNSENT Slack draft in the user's Slack app for them to review and send manually. " +
			"Does NOT post. Compose the full message text yourself and pass it in `message`.",
		snippet: "Create an unsent Slack draft (does not send)",
		parameters: Type.Object({
			channel_id: S({ description: "Target channel or DM ID." }),
			message: S({ description: "Full message text (compose it yourself; markdown supported)." }),
			thread_ts: opt(S({ description: "Reply in this thread (root message ts)." })),
		}),
	},
	{
		name: "slack_send_message",
		label: "Slack send",
		description: "POST a message to a Slack channel or DM immediately. This actually sends.",
		snippet: "Send a Slack message (posts immediately)",
		destructive: true,
		parameters: Type.Object({
			channel_id: S({ description: "Target channel or DM ID." }),
			message: S({ description: "Full message text to post." }),
			draft_id: opt(S({ description: "Send an existing draft by ID instead of new text." })),
			reply_broadcast: opt(B()),
			thread_ts: opt(S({ description: "Reply in this thread (root message ts)." })),
			skip_approval: skipApproval,
		}),
	},
	{
		name: "slack_schedule_message",
		label: "Slack schedule",
		description: "Schedule a Slack message to post at a future time (post_at, unix seconds). This will send.",
		snippet: "Schedule a Slack message for later",
		destructive: true,
		parameters: Type.Object({
			channel_id: S({ description: "Target channel or DM ID." }),
			message: S({ description: "Full message text to post." }),
			post_at: I({ description: "When to post, as a Unix timestamp in seconds." }),
			reply_broadcast: opt(B()),
			thread_ts: opt(S()),
			skip_approval: skipApproval,
		}),
	},
	{
		name: "slack_create_canvas",
		label: "Slack create canvas",
		description: "Create a new Slack canvas. This writes to Slack.",
		snippet: "Create a Slack canvas",
		destructive: true,
		parameters: Type.Object({
			title: S({ description: "Canvas title." }),
			content: S({ description: "Canvas content (markdown)." }),
			skip_approval: skipApproval,
		}),
	},
	{
		name: "slack_update_canvas",
		label: "Slack update canvas",
		description: "Update an existing Slack canvas. This writes to Slack.",
		snippet: "Update a Slack canvas",
		destructive: true,
		parameters: Type.Object({
			canvas_id: S({ description: "Canvas ID to update." }),
			action: S({ description: "Update action, e.g. 'replace', 'insert_after', 'insert_before'." }),
			content: S({ description: "New content (markdown)." }),
			section_id: opt(S({ description: "Target section ID for insert actions." })),
			skip_approval: skipApproval,
		}),
	},
];

// ---------------------------------------------------------------------------
// Rendering (collapsible tool output)
// ---------------------------------------------------------------------------

function renderCall(shortName: string) {
	return (args: unknown, theme: { fg: (c: string, s: string) => string; bold: (s: string) => string }) => {
		const a = (args as Record<string, unknown>) ?? {};
		const summary = a.query
			? String(a.query)
			: a.channel_id
				? String(a.channel_id)
				: a.canvas_id
					? String(a.canvas_id)
					: a.user_id
						? String(a.user_id)
						: "";
		const title = theme.fg("toolTitle", theme.bold(shortName));
		const tail = summary ? theme.fg("muted", ` ${summary}`) : "";
		return new Text(`${title}${tail}`, 0, 0);
	};
}

function renderResult(
	result: { content?: Array<{ type: string; text?: string }> },
	options: { expanded?: boolean; isPartial?: boolean },
	theme: { fg: (c: string, s: string) => string },
) {
	const text = result.content?.[0]?.type === "text" ? (result.content[0].text ?? "") : "";
	if (options.isPartial) return new Text(theme.fg("muted", text || "Working…"), 0, 0);
	const lines = text.split("\n");
	if (options.expanded) {
		return new Text(lines.map((l) => theme.fg("toolOutput", l)).join("\n"), 0, 0);
	}
	const first = lines.find((l) => l.trim().length > 0) ?? "";
	const preview = first.length > 100 ? `${first.slice(0, 100)}…` : first;
	const more = lines.length > 1 ? theme.fg("muted", ` (+${lines.length - 1} lines, expand to view)`) : "";
	return new Text(`${theme.fg("toolOutput", preview)}${more}`, 0, 0);
}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

export default function slackExtension(pi: ExtensionAPI) {
	for (const def of TOOL_DEFS) {
		const fullName = prefix(def.name);
		const destructive = def.destructive === true;

		pi.registerTool({
			name: def.name,
			label: def.label,
			description: def.description,
			promptSnippet: def.snippet,
			parameters: def.parameters,

			async execute(_toolCallId, params, signal, onUpdate, ctx) {
				const sig = signal ?? new AbortController().signal;
				const fail = (text: string) => ({ content: [{ type: "text" as const, text }], isError: true });

				const { skip_approval, ...rest } = params as Static<typeof def.parameters> & {
					skip_approval?: boolean;
				};
				const args = Object.fromEntries(
					Object.entries(rest).filter(([, v]) => v !== undefined),
				) as Record<string, unknown>;

				if (destructive && !skip_approval) {
					const summary = JSON.stringify(args, null, 2);
					if (ctx.mode !== "tui") {
						return fail(
							`Refusing to run ${def.name}: approval required but no interactive TUI is available. ` +
								`Requested args:\n${summary}`,
						);
					}
					const ok = await ctx.ui.confirm(`Run Slack: ${def.name}?`, summary);
					if (!ok) {
						return {
							content: [{ type: "text", text: `Cancelled by user. Requested args:\n${summary}` }],
							details: { tool: def.name, cancelled: true },
						};
					}
				}

				onUpdate?.({ content: [{ type: "text", text: `Running ${def.name} via claude…` }] });
				try {
					const raw = await runSlackTool(fullName, args, sig);
					return { content: [{ type: "text", text: raw || "(no result)" }], details: { tool: def.name } };
				} catch (e) {
					return fail(`${def.name} failed: ${e instanceof Error ? e.message : String(e)}`);
				}
			},

			renderCall: renderCall(def.name),
			renderResult,
		});
	}
}
