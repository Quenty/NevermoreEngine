import { describe, it, expect, afterEach } from 'vitest';
import { findPluginsFolder } from '../../src/studio-process.js';

describe('findPluginsFolder', () => {
  const originalPlatform = process.platform;
  const originalEnv = { ...process.env };

  afterEach(() => {
    Object.defineProperty(process, 'platform', { value: originalPlatform });
    process.env = { ...originalEnv };
  });

  it('returns correct Windows path', () => {
    Object.defineProperty(process, 'platform', { value: 'win32' });
    process.env.LOCALAPPDATA = 'C:\\Users\\Test\\AppData\\Local';

    const result = findPluginsFolder();
    expect(result).toMatch(/Roblox[/\\]Plugins$/);
    expect(result).toContain('C:\\Users\\Test\\AppData\\Local');
  });

  it('returns correct macOS path', () => {
    Object.defineProperty(process, 'platform', { value: 'darwin' });
    process.env.HOME = '/Users/test';

    const result = findPluginsFolder();
    // path.join on Windows normalizes separators to backslash, so we check
    // the components rather than literal forward slashes.
    expect(result).toContain('Users');
    expect(result).toContain('test');
    expect(result).toMatch(/Roblox[/\\]Plugins$/);
  });

  it('throws on unsupported platform', () => {
    Object.defineProperty(process, 'platform', { value: 'linux' });

    expect(() => findPluginsFolder()).toThrow('Unsupported platform');
  });

  it('throws when LOCALAPPDATA is missing on Windows', () => {
    Object.defineProperty(process, 'platform', { value: 'win32' });
    delete process.env.LOCALAPPDATA;

    expect(() => findPluginsFolder()).toThrow('LOCALAPPDATA');
  });

  it('throws when HOME is missing on macOS', () => {
    Object.defineProperty(process, 'platform', { value: 'darwin' });
    delete process.env.HOME;

    expect(() => findPluginsFolder()).toThrow('HOME');
  });
});
