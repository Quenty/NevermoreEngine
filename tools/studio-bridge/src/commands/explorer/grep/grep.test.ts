import { describe, it, expect, vi } from 'vitest';
import { formatGrepText, grepScriptsHandlerAsync } from './grep.js';

describe('grepScriptsHandlerAsync', () => {
  it('reports each match as path:line: text', async () => {
    const session = {
      grepScriptsAsync: vi.fn().mockResolvedValue({
        matches: [
          {
            path: 'ServerScriptService.Main',
            className: 'Script',
            line: 4,
            text: '\tlocal damage = 10',
          },
          {
            path: 'ServerScriptService.Main',
            className: 'Script',
            line: 9,
            text: 'damage += 1',
          },
        ],
        searched: 12,
        truncated: false,
      }),
    } as any;

    const result = await grepScriptsHandlerAsync(session, {
      pattern: 'damage',
      caseSensitive: true,
    });

    expect(session.grepScriptsAsync).toHaveBeenCalledWith({
      pattern: 'damage',
      caseSensitive: true,
      root: undefined,
      luaPattern: undefined,
      limit: undefined,
    });
    expect(result.summary).toBe('2 matching line(s) in 1 of 12 scripts');

    const text = formatGrepText(result);
    expect(text).toContain('ServerScriptService.Main');
    expect(text).toContain('local damage = 10');
  });
});
