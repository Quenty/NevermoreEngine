/**
 * Characterization tests for how Open Cloud actually delivers a Luau execution
 * task's logs and return value. Nothing here tests our code: every assertion is
 * a claim about Roblox's behaviour that our log handling is built on, written
 * so the claim fails out loud if Roblox changes it.
 *
 * These claims decide real things — whether a truncated run is worth
 * re-fetching, whether `maxPageSize` is worth sending, whether a batch package
 * with no output was dropped or never ran — and none of them are documented by
 * Roblox. Prose in a gotchas file cannot notice when it goes stale. This can.
 *
 * Disabled by default: it spends real Open Cloud quota. To run it:
 *
 *   NEVERMORE_CHARACTERIZATION=1 npm test -- open-cloud-logs
 *
 * It reads the key through the same credential store the CLI uses, so
 * `nevermore auth login` is the only setup. The universe and place default to
 * the nevermore-test-runner test target and can be pointed elsewhere with
 * NEVERMORE_CHARACTERIZATION_UNIVERSE / _PLACE.
 */

import { describe, it, expect, beforeAll } from 'vitest';
import { loadStoredApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import {
  OpenCloudClient,
  getTaskReturnValues,
  type LuauTask,
} from './open-cloud-client.js';
import { RateLimiter } from './rate-limiter.js';

const ENABLED = process.env.NEVERMORE_CHARACTERIZATION === '1';

/** The nevermore-test-runner test target, which exists to be run against. */
const UNIVERSE_ID = Number(
  process.env.NEVERMORE_CHARACTERIZATION_UNIVERSE ?? 9716264427
);
const PLACE_ID = Number(
  process.env.NEVERMORE_CHARACTERIZATION_PLACE ?? 138951894938783
);

const LINES_THAT_FIT = 5_000;
const LINES_AT_CAPACITY = 8_000;
const LINES_THAT_OVERFLOW_LESS = 10_000;
const LINES_THAT_OVERFLOW = 20_000;

/**
 * Retention is bounded by memory, and each retained message costs this many
 * bytes beyond its own text — timestamp, type and framing. Derived by holding
 * the print count at 20,000 and varying only the payload width, then solving
 * `chars + k * messages` for the k that makes that budget constant.
 */
const PER_MESSAGE_OVERHEAD_BYTES = 47;

/** A printed line that names its own position, so survivors identify themselves. */
const SEQ = new RegExp('^SEQ (' + String.raw`\d` + '+)');

describe.runIf(ENABLED)('Open Cloud task log delivery', () => {
  let client: OpenCloudClient;
  let placeVersion: number;

  beforeAll(async () => {
    const apiKey = await loadStoredApiKeyAsync();
    if (!apiKey) {
      throw new Error(
        'No stored Open Cloud API key. Run `nevermore auth login` first.'
      );
    }

    client = new OpenCloudClient({ apiKey, rateLimiter: new RateLimiter() });
    placeVersion = await client.resolveLatestPlaceVersionAsync(
      UNIVERSE_ID,
      PLACE_ID,
      'saved'
    );
  }, 120_000);

  /**
   * Run a task printing `lines` numbered messages, each optionally padded to
   * widen it, and report what came back.
   */
  async function printLinesAsync(lines: number, padChars = 0) {
    const script = padChars
      ? `local pad = string.rep("p", ${padChars}) for i = 1, ${lines} do print("SEQ " .. i .. " " .. pad) end`
      : `for i = 1, ${lines} do print("SEQ " .. i) end`;

    const task = await client.createExecutionTaskAsync(
      UNIVERSE_ID,
      PLACE_ID,
      placeVersion,
      script,
      300_000
    );
    const completed = await client.pollTaskCompletionAsync(task.path);
    expect(completed.state).toBe('COMPLETE');

    const fetched = await client.getRawTaskLogsAsync(completed.path);
    const seq = fetched.text
      .split('\n')
      .map((line) => SEQ.exec(line.trim())?.[1])
      .filter((n): n is string => n !== undefined)
      .map(Number);

    return { task: completed, ...fetched, seq };
  }

  /** Bytes the buffer spent on what it kept, per-message overhead included. */
  function retainedBudget(run: { stats: { chars: number; messages: number } }) {
    return run.stats.chars + PER_MESSAGE_OVERHEAD_BYTES * run.stats.messages;
  }

  it('delivers a small run complete and in order', async () => {
    const run = await printLinesAsync(LINES_THAT_FIT);

    expect(run.seq).toHaveLength(LINES_THAT_FIT);
    expect(run.seq[0]).toBe(1);
    expect(run.seq[run.seq.length - 1]).toBe(LINES_THAT_FIT);
    // Arrival order is chronological, so no client-side sort is needed — and
    // sorting by createTime would be wrong, since a whole frame shares one.
    expect(run.seq).toEqual([...run.seq].sort((a, b) => a - b));
  }, 300_000);

  it('truncates a large run by dropping the head, keeping a contiguous tail', async () => {
    // Says a short log is missing output rather than proof a run printed
    // little, and rules out the loss being a page we failed to request — an
    // unrequested page would have held the head. It is why the batch parser
    // closes sections on their END marker.
    const run = await printLinesAsync(LINES_THAT_OVERFLOW);

    expect(run.seq.length).toBeLessThan(LINES_THAT_OVERFLOW);
    expect(run.seq[run.seq.length - 1]).toBe(LINES_THAT_OVERFLOW);
    expect(run.seq[0]).toBeGreaterThan(1);
    expect(run.seq).toEqual(
      Array.from({ length: run.seq.length }, (_, i) => run.seq[0] + i)
    );
  }, 300_000);

  it('bounds retention by memory, not by number of print calls', async () => {
    // Both runs make exactly the same number of print calls. If the buffer held
    // a fixed number of messages they would retain the same count; the padded
    // one keeps a small fraction of it, so the budget is bytes.
    const narrow = await printLinesAsync(LINES_THAT_OVERFLOW);
    const wide = await printLinesAsync(LINES_THAT_OVERFLOW, 500);

    expect(wide.stats.messages).toBeLessThan(narrow.stats.messages / 5);
    expect(wide.stats.chars).toBeGreaterThan(narrow.stats.chars);

    // And it is one budget in both: bytes kept, plus a fixed cost per message,
    // lands on the same number however wide the messages are. ~450 KB.
    expect(retainedBudget(wide)).toBeGreaterThan(retainedBudget(narrow) * 0.95);
    expect(retainedBudget(wide)).toBeLessThan(retainedBudget(narrow) * 1.05);
    expect(retainedBudget(narrow)).toBeGreaterThan(400_000);
    expect(retainedBudget(narrow)).toBeLessThan(500_000);
  }, 300_000);

  it('keeps the same amount however much is printed, at one message width', async () => {
    // The corollary: at a fixed message size, printing twice as much does not
    // get twice as much back. A long run cannot be made to report itself by
    // printing more carefully, which is why counts travel in the return value.
    const atCapacity = await printLinesAsync(LINES_AT_CAPACITY);
    expect(atCapacity.seq).toHaveLength(LINES_AT_CAPACITY);

    const over = await printLinesAsync(LINES_THAT_OVERFLOW_LESS);
    const wayOver = await printLinesAsync(LINES_THAT_OVERFLOW);

    expect(over.seq.length).toBeLessThan(LINES_THAT_OVERFLOW_LESS);
    expect(wayOver.seq.length).toBeLessThan(LINES_THAT_OVERFLOW);
    expect(wayOver.seq.length).toBeGreaterThan(over.seq.length * 0.9);
    expect(wayOver.seq.length).toBeLessThan(over.seq.length * 1.1);
  }, 300_000);

  it('returns only what the task printed, with nothing of its own mixed in', async () => {
    // Rules out engine or internal messages taking room in the buffer: every
    // message that came back is one of ours, so a retained count short of a
    // round number is the byte budget, not foreign output.
    const run = await printLinesAsync(LINES_THAT_OVERFLOW);

    expect(run.seq).toHaveLength(run.stats.messages);
  }, 300_000);

  it('delivers the same messages structured or flat, and never a second page', async () => {
    // Why we send no maxPageSize, and why the view is a free choice: asking for
    // 10 still returns the whole window in one page. A page size that counted
    // messages would cap this at 10 and hand back a token for the rest.
    const run = await printLinesAsync(LINES_THAT_OVERFLOW);

    const structured = await fetchOnePageAsync(run.task.path, {
      view: 'STRUCTURED',
    });
    const flat = await fetchOnePageAsync(run.task.path, {});

    // Same messages in the same order — the view changes the envelope, not the
    // delivery.
    expect(flat.messages).toEqual(structured.messages);
    expect(structured.messages).toHaveLength(run.stats.messages);

    const variants: Array<Record<string, string>> = [
      { view: 'STRUCTURED', maxPageSize: '10' },
      { view: 'STRUCTURED', maxPageSize: '100' },
      { maxPageSize: '10' },
    ];

    for (const params of variants) {
      const page = await fetchOnePageAsync(run.task.path, params);
      expect(page.nextPageToken).toBeUndefined();
      expect(page.messages).toEqual(structured.messages);
    }
  }, 300_000);

  it('delivers a large return value, but drops the task entirely past a limit', async () => {
    // Why the returned failure list is capped rather than trusted to arrive: an
    // oversize return value does not come back truncated, it takes the whole
    // run with it — and such a task carries no output and no message saying so,
    // which is why "nothing came back" must stay distinguishable from "the
    // script returned nothing".
    const twoMegabytes = await returnStringAsync(2 * 1024 * 1024);
    expect(twoMegabytes.state).toBe('COMPLETE');
    expect(getTaskReturnValues(twoMegabytes)).toHaveLength(1);

    const fiveMegabytes = await returnStringAsync(5 * 1024 * 1024);
    expect(fiveMegabytes.state).not.toBe('COMPLETE');
    expect(getTaskReturnValues(fiveMegabytes)).toBeUndefined();
  }, 300_000);

  /** Run a task returning a string of `bytes`, and wait for whatever happens. */
  async function returnStringAsync(bytes: number): Promise<LuauTask> {
    const task = await client.createExecutionTaskAsync(
      UNIVERSE_ID,
      PLACE_ID,
      placeVersion,
      `return string.rep("x", ${bytes})`,
      300_000
    );

    // Returns on any terminal state, failure included — which is one of the
    // outcomes under test here, not an error.
    return client.pollTaskCompletionAsync(task.path);
  }

  /**
   * One raw request, bypassing the client so the query can be varied. Returns
   * only what the claims above are about.
   */
  async function fetchOnePageAsync(
    taskPath: string,
    params: Record<string, string>
  ): Promise<{ nextPageToken?: string; messages: string[] }> {
    const apiKey = (await loadStoredApiKeyAsync())!;
    const url = new URL(`https://apis.roblox.com/cloud/v2/${taskPath}/logs`);
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }

    const response = await fetch(url.toString(), {
      headers: { 'X-API-Key': apiKey },
    });
    expect(response.ok).toBe(true);

    const data = (await response.json()) as {
      luauExecutionSessionTaskLogs?: Array<{
        messages?: string[];
        structuredMessages?: Array<{ message: string }>;
      }>;
      nextPageToken?: string;
    };

    const messages: string[] = [];
    for (const entry of data.luauExecutionSessionTaskLogs ?? []) {
      if (entry.structuredMessages?.length) {
        messages.push(...entry.structuredMessages.map((m) => m.message));
      } else if (entry.messages?.length) {
        messages.push(...entry.messages);
      }
    }

    return { nextPageToken: data.nextPageToken || undefined, messages };
  }
});
