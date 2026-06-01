import { describe, it } from "node:test";
import assert from "node:assert/strict";

import {
  RECENT_RESOLVED_MS,
  selectStatusFromUpdog,
  type UpdogPayload,
} from "../anthropic-status.ts";

const NOW = 1_700_000_000_000;

function payload(outages: UpdogPayload["data"] extends infer D ? any : never): UpdogPayload {
  return { data: { attributes: { provider_data: [{ provider_name: "anthropic", outages }] } } };
}

describe("selectStatusFromUpdog", () => {
  it("returns unknown when the provider is absent", () => {
    const p: UpdogPayload = { data: { attributes: { provider_data: [] } } };
    assert.equal(selectStatusFromUpdog(p, NOW).level, "unknown");
  });

  it("returns operational when there are no outages", () => {
    assert.equal(selectStatusFromUpdog(payload([]), NOW).level, "operational");
  });

  it("treats an outage without an end timestamp as active", () => {
    const result = selectStatusFromUpdog(
      payload([
        {
          start: NOW - 60_000,
          linked_status_page_incidents: [
            { start: NOW - 60_000, title: "API errors", url: "https://status.example/i/1" },
          ],
        },
      ]),
      NOW,
    );
    assert.equal(result.level, "outage");
    assert.equal(result.title, "API errors");
    assert.equal(result.incidentUrl, "https://status.example/i/1");
    assert.equal(result.outageStart, NOW - 60_000);
  });

  it("treats status !== resolved as active even when end is set", () => {
    const result = selectStatusFromUpdog(
      payload([{ start: NOW - 120_000, end: NOW - 60_000, status: "investigating" }]),
      NOW,
    );
    assert.equal(result.level, "outage");
    assert.equal(result.title, "Service disruption");
  });

  it("picks the most recent active outage regardless of array order", () => {
    const result = selectStatusFromUpdog(
      payload([
        {
          start: NOW - 10 * 60_000,
          linked_status_page_incidents: [{ start: NOW - 10 * 60_000, title: "Old" }],
        },
        {
          start: NOW - 60_000,
          linked_status_page_incidents: [{ start: NOW - 60_000, title: "New" }],
        },
      ]),
      NOW,
    );
    assert.equal(result.title, "New");
  });

  it("falls back to degraded when an outage ended inside the window", () => {
    const end = NOW - (RECENT_RESOLVED_MS / 2);
    const result = selectStatusFromUpdog(
      payload([{ start: end - 300_000, end, status: "resolved" }]),
      NOW,
    );
    assert.equal(result.level, "degraded");
    assert.equal(result.outageEnd, end);
  });

  it("picks the most recently ended outage for the degraded fallback", () => {
    const older = NOW - (RECENT_RESOLVED_MS / 2);
    const newer = NOW - 60_000;
    const result = selectStatusFromUpdog(
      payload([
        { start: older - 1, end: older, status: "resolved" },
        { start: newer - 1, end: newer, status: "resolved" },
      ]),
      NOW,
    );
    assert.equal(result.level, "degraded");
    assert.equal(result.outageEnd, newer);
  });

  it("ignores outages resolved outside the window", () => {
    const result = selectStatusFromUpdog(
      payload([
        { start: NOW - RECENT_RESOLVED_MS - 10_000, end: NOW - RECENT_RESOLVED_MS - 1, status: "resolved" },
      ]),
      NOW,
    );
    assert.equal(result.level, "operational");
  });

  it("does not mutate the caller's outage array", () => {
    const outages = [
      { start: NOW - 10_000, end: NOW - 5_000, status: "resolved" as const },
      { start: NOW - 20_000, end: NOW - 15_000, status: "resolved" as const },
    ];
    const snapshot = JSON.stringify(outages);
    selectStatusFromUpdog(payload(outages), NOW);
    assert.equal(JSON.stringify(outages), snapshot);
  });

  it("provides graceful fallbacks when linked incidents are missing", () => {
    const result = selectStatusFromUpdog(
      payload([{ start: NOW - 60_000 }]),
      NOW,
    );
    assert.equal(result.level, "outage");
    assert.equal(result.title, "Service disruption");
    assert.ok(result.incidentUrl?.includes("updog.ai"));
  });
});
