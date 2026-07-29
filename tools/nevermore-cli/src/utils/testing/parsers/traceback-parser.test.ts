import { describe, expect, it } from 'vitest';

import {
  formatTracebacks,
  ownerOf,
  parseTracebacks,
} from './traceback-parser.js';

const TRACEBACK = [
  'PlayerBadgeHelper: attempt to index nil with UserId',
  'Stack Begin',
  'Script \'[string "ServerScriptService.egghunt2026.game.Server.PlayerBadgeHelper"]\', Line 365 - function _awardBadge',
  'Script \'[string "ServerScriptService.egghunt2026.game.Server.PlayerBadgeHelper"]\', Line 138',
  'Stack End',
].join('\n');

describe('parseTracebacks', () => {
  it('attributes a traceback to the package that owns the failing script', () => {
    const [traceback] = parseTracebacks(TRACEBACK);

    expect(traceback.owner).toBe('egghunt2026');
    expect(traceback.source).toContain('PlayerBadgeHelper');
    expect(traceback.message).toContain('attempt to index nil');
  });

  it('collapses repeats of the same crash into one entry with a count', () => {
    // One bug fires per player per frame, so raw output can hold hundreds of
    // identical copies. Printing them all is what makes logs unreadable.
    const repeated = [TRACEBACK, TRACEBACK, TRACEBACK].join('\n');

    const tracebacks = parseTracebacks(repeated);

    expect(tracebacks).toHaveLength(1);
    expect(tracebacks[0].count).toBe(3);
  });

  it('keeps distinct crashes apart', () => {
    const other = TRACEBACK.replace('PlayerBadgeHelper', 'TrainHelper');

    expect(parseTracebacks([TRACEBACK, other].join('\n'))).toHaveLength(2);
  });

  it('finds nothing in clean output', () => {
    expect(parseTracebacks('Tests: 10 passed, 10 total')).toEqual([]);
  });
});

describe('ownerOf', () => {
  it('names the package below the service', () => {
    expect(ownerOf('ServerScriptService.brio.Foo.Bar')).toBe('brio');
  });
});

describe('formatTracebacks', () => {
  it('bounds how many it prints and says how many it withheld', () => {
    const many = Array.from({ length: 8 }, (_, i) =>
      TRACEBACK.replace('PlayerBadgeHelper:', `Helper${i}:`)
    ).join('\n');

    const formatted = formatTracebacks(parseTracebacks(many), 5);

    expect(formatted).toContain('and 3 more distinct traceback(s)');
  });
});
