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
  it('plants the Shared modules with the plugin version filled in', async () => {
    const bridge = await buildPlaytestBridgeAsync();

    expect(Object.keys(bridge.modules)).toContain('StudioBridgeClient');
    expect(Object.keys(bridge.modules)).toContain('PrecompiledSources');
    expect(Object.keys(bridge.modules).some((n) => n.endsWith('.spec'))).toBe(
      false
    );
    expect(bridge.modules.StudioBridgeSessionUtils).not.toContain(
      '{{PLUGIN_VERSION}}'
    );
    expect(bridge.entrySource).toContain('StudioBridgeClient.start');
  });

  it('precompiles every action plus the given scripts', async () => {
    const bridge = await buildPlaytestBridgeAsync(['return "mine"']);

    expect(bridge.precompiled.some((s) => s.includes('return "mine"'))).toBe(
      true
    );
    expect(bridge.precompiled.some((s) => s.includes('ExecuteAction'))).toBe(
      true
    );
  });
});
