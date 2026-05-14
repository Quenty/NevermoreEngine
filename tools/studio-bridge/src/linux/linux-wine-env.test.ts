import { describe, it, expect } from 'vitest';
import { buildWineEnv } from './linux-wine-env.js';
import type { LinuxStudioConfig } from './linux-config.js';

function makeConfig(overrides?: Partial<LinuxStudioConfig>): LinuxStudioConfig {
  return {
    studioDir: '/home/test/roblox-studio',
    winePrefix: '/home/test/.wine',
    display: ':99',
    studioExe: '/home/test/roblox-studio/RobloxStudioBeta.exe',
    clientSettingsPath:
      '/home/test/roblox-studio/ClientSettings/ClientAppSettings.json',
    shadersDir: '/home/test/roblox-studio/shaders',
    pluginsDir: '/home/test/roblox-studio/Plugins',
    writeCredExe: '/home/test/roblox-studio/write-cred.exe',
    ...overrides,
  };
}

describe('buildWineEnv', () => {
  it('includes DISPLAY from config', () => {
    const env = buildWineEnv(makeConfig({ display: ':42' }));
    expect(env.DISPLAY).toBe(':42');
  });

  it('includes WINEPREFIX from config', () => {
    const env = buildWineEnv(makeConfig({ winePrefix: '/tmp/wine' }));
    expect(env.WINEPREFIX).toBe('/tmp/wine');
  });

  it('sets WINEARCH to win64', () => {
    const env = buildWineEnv(makeConfig());
    expect(env.WINEARCH).toBe('win64');
  });

  it('suppresses Wine debug output', () => {
    const env = buildWineEnv(makeConfig());
    expect(env.WINEDEBUG).toBe('-all');
  });

  it('suppresses Mono/Gecko install dialogs', () => {
    const env = buildWineEnv(makeConfig());
    expect(env.WINEDLLOVERRIDES).toBe('mscoree=d;mshtml=d');
  });

  it('sets Mesa GL version overrides', () => {
    const env = buildWineEnv(makeConfig());
    expect(env.MESA_GL_VERSION_OVERRIDE).toBe('4.5');
    expect(env.MESA_GLSL_VERSION_OVERRIDE).toBe('450');
  });

  it('preserves PATH from process.env', () => {
    const env = buildWineEnv(makeConfig());
    expect(env.PATH).toBe(process.env.PATH);
  });
});
