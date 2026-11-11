import { describe, it, expect, afterEach } from 'vitest';
import {
  findPluginsFolder,
  buildStudioLaunchArg,
} from './studio-process-manager.js';

describe('buildStudioLaunchArg', () => {
  it('builds an EditPlace deep-link from place + universe ids', () => {
    expect(
      buildStudioLaunchArg({ placeId: 84760113521251, universeId: 9893751595 })
    ).toBe(
      'roblox-studio:1+launchmode:edit+task:EditPlace+placeId:84760113521251+universeId:9893751595'
    );
  });

  it('omits universeId from the deep-link when not provided', () => {
    expect(buildStudioLaunchArg({ placeId: 123 })).toBe(
      'roblox-studio:1+launchmode:edit+task:EditPlace+placeId:123'
    );
  });

  it('prefers the cloud place id over a local place path', () => {
    expect(
      buildStudioLaunchArg({ placeId: 5, placePath: '/tmp/game.rbxl' })
    ).toContain('placeId:5');
  });

  it('returns the local place path when no place id is given', () => {
    expect(buildStudioLaunchArg({ placePath: '/tmp/game.rbxl' })).toBe(
      '/tmp/game.rbxl'
    );
  });

  it('returns an empty string for no place at all', () => {
    expect(buildStudioLaunchArg({})).toBe('');
  });
});

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

  it('returns correct Linux path using WINEPREFIX', () => {
    Object.defineProperty(process, 'platform', { value: 'linux' });
    process.env.WINEPREFIX = '/home/test/.wine';
    process.env.USER = 'testuser';

    const result = findPluginsFolder();
    expect(result).toMatch(/Plugins$/);
    expect(result).toContain('/home/test/.wine/drive_c/users/testuser');
    expect(result).toContain('Roblox');
  });

  it('returns correct Linux path with default Wine prefix', () => {
    Object.defineProperty(process, 'platform', { value: 'linux' });
    delete process.env.WINEPREFIX;

    const result = findPluginsFolder();
    expect(result).toMatch(/Plugins$/);
    expect(result).toContain('.wine');
    expect(result).toContain('Roblox');
  });

  it('throws on unsupported platform', () => {
    Object.defineProperty(process, 'platform', { value: 'freebsd' });

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
