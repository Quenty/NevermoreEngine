import { describe, expect, it } from 'vitest';
import { matchProcessByUptime } from './studio-process-identity.js';

describe('matchProcessByUptime', () => {
  const now = 1_000_000_000;
  const processes = [
    { pid: 1, startedAt: now - 300_000 },
    { pid: 2, startedAt: now - 260_000 },
    { pid: 3 },
  ];

  it('picks the process started when the uptime says', () => {
    expect(
      matchProcessByUptime(processes, { uptimeSec: 260.4, observedAt: now })
        ?.pid
    ).toBe(2);
  });

  it('allows for the clock starting after the process and drifting with age', () => {
    expect(
      matchProcessByUptime([{ pid: 9, startedAt: now - 3_600_000 - 10_000 }], {
        uptimeSec: 3600,
        observedAt: now,
      })?.pid
    ).toBe(9);
  });

  it('matches a Studio whose os.clock() started ~7s after its process', () => {
    expect(
      matchProcessByUptime([{ pid: 9, startedAt: now - 600_000 }], {
        uptimeSec: 593,
        observedAt: now,
      })?.pid
    ).toBe(9);
  });

  it('finds nothing outside the tolerance', () => {
    expect(
      matchProcessByUptime(processes, { uptimeSec: 200, observedAt: now })
    ).toBeUndefined();
    expect(
      matchProcessByUptime(processes, { uptimeSec: 320, observedAt: now })
    ).toBeUndefined();
  });

  it('tells apart two processes started 10s apart by the usual clock lag', () => {
    const pair = [
      { pid: 1, startedAt: now - 110_000 },
      { pid: 2, startedAt: now - 100_000 },
    ];
    expect(
      matchProcessByUptime(pair, { uptimeSec: 93, observedAt: now })?.pid
    ).toBe(2);
    expect(
      matchProcessByUptime(pair, { uptimeSec: 103, observedAt: now })?.pid
    ).toBe(1);
  });

  it('refuses to choose between two processes started together', () => {
    expect(
      matchProcessByUptime(
        [
          { pid: 1, startedAt: now - 102_000 },
          { pid: 2, startedAt: now - 100_000 },
        ],
        { uptimeSec: 94, observedAt: now }
      )
    ).toBeUndefined();
  });
});
