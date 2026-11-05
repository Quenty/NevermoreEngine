import { describe, expect, it } from 'vitest';
import { matchProcessByUptime } from './studio-process-identity.js';

describe('matchProcessByUptime', () => {
  const now = 1_000_000_000;
  const processes = [
    { pid: 1, startedAt: now - 300_000 },
    { pid: 2, startedAt: now - 290_000 },
    { pid: 3 },
  ];

  it('picks the process started when the uptime says', () => {
    expect(
      matchProcessByUptime(processes, { uptimeSec: 290.4, observedAt: now })
        ?.pid
    ).toBe(2);
  });

  it('finds nothing outside the tolerance', () => {
    expect(
      matchProcessByUptime(processes, { uptimeSec: 250, observedAt: now })
    ).toBeUndefined();
  });

  it('refuses to choose between two processes started together', () => {
    expect(
      matchProcessByUptime(
        [
          { pid: 1, startedAt: now - 100_000 },
          { pid: 2, startedAt: now - 100_500 },
        ],
        { uptimeSec: 100.2, observedAt: now }
      )
    ).toBeUndefined();
  });
});
