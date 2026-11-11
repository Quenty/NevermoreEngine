import { describe, it, expect } from 'vitest';
import { describeLogVolume, type LogFetchStats } from './log-fetch-stats.js';

const STATS: LogFetchStats = {
  requests: 1,
  pages: 1,
  entries: 1,
  messages: 7627,
  chars: 276989,
};

describe('describeLogVolume', () => {
  it('reports lines and chars alongside the shape of the fetch', () => {
    const description = describeLogVolume('a\nb\nc', STATS);

    expect(description).toContain('5 chars, 3 line(s) received');
    expect(description).toContain('1 API call(s)');
    expect(description).toContain('1 page(s)');
    expect(description).toContain('1 log entry(ies)');
    expect(description).toContain('7627 message(s)');
  });

  it('separates entries from messages', () => {
    // The two are orders of magnitude apart and only one of them is a line
    // count. A reader that takes "1 entry" for "1 line" concludes the run
    // printed nothing, when 7627 messages arrived inside that entry.
    const description = describeLogVolume('', STATS);

    expect(description).toContain('1 log entry(ies), 7627 message(s)');
  });

  it('counts no lines in empty logs', () => {
    // Splitting '' yields one empty line, which would report a run that
    // produced nothing as having produced a line.
    expect(describeLogVolume('', STATS)).toContain('0 chars, 0 line(s)');
  });

  it('says the fetch is unmeasured rather than empty when it is unknown', () => {
    // A local run reads its logs off the Studio bridge, where there is no
    // request to count. Zeroes there would read as a fetch that returned
    // nothing, which is a different fault entirely.
    const description = describeLogVolume('a\nb', undefined);

    expect(description).toContain('3 chars, 2 line(s) received');
    expect(description).toContain('no fetch stats');
    expect(description).not.toContain('0 API call(s)');
  });
});
