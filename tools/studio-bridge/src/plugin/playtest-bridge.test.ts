import { describe, it, expect } from 'vitest';
import {
  buildPlaytestBridgeAsync,
  wrapPrecompiledSource,
} from './playtest-bridge.js';

describe('wrapPrecompiledSource', () => {
  it('opens the function on the first line', () => {
    const wrapped = wrapPrecompiledSource('return 1');
    expect(wrapped.split('\n')[0]).toBe('return { fn = function(...) return 1');
  });

  it('uses a long string level the source does not close', () => {
    expect(wrapPrecompiledSource('return "]]"')).toContain('[=[x');
    expect(wrapPrecompiledSource('return "]]" .. "]=]"')).toContain('[==[x');
  });

  it('does not let a trailing ] close the string early', () => {
    const wrapped = wrapPrecompiledSource('local t = {}\nreturn t[1]');
    expect(wrapped).toContain('[=[x');
  });

  it('keeps a leading newline in the source text', () => {
    expect(wrapPrecompiledSource('\nreturn 1')).toContain('[[x\nreturn 1]]');
  });
});

describe('buildPlaytestBridgeAsync', () => {
  it('asks for a client copy only when told to', async () => {
    expect((await buildPlaytestBridgeAsync()).client).toBeUndefined();
    expect(
      (await buildPlaytestBridgeAsync([], { withClient: true })).client
    ).toBe(true);
  });

  it('precompiles only the given scripts, since the plugin plants its actions', async () => {
    const bridge = await buildPlaytestBridgeAsync([
      'return "mine"',
      'return "mine"',
    ]);

    expect(bridge.precompiled).toHaveLength(1);
    expect(bridge.precompiled[0]).toContain('return "mine"');
  });
});
