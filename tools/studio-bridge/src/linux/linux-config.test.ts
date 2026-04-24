import { describe, it, expect, afterEach } from 'vitest';
import { resolveLinuxConfig, STUDIO_PACKAGES } from './linux-config.js';

describe('resolveLinuxConfig', () => {
  const originalEnv = { ...process.env };

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  it('returns HOME-based defaults when no env vars set', () => {
    delete process.env.STUDIO_DIR;
    delete process.env.WINEPREFIX;
    delete process.env.DISPLAY;
    process.env.HOME = '/home/testuser';

    const config = resolveLinuxConfig();
    expect(config.studioDir).toContain('roblox-studio');
    expect(config.winePrefix).toContain('.wine');
    expect(config.display).toBe(':99');
    expect(config.studioExe).toMatch(/RobloxStudioBeta\.exe$/);
    expect(config.clientSettingsPath).toContain('ClientAppSettings.json');
    expect(config.pluginsDir).toMatch(/Plugins$/);
    expect(config.writeCredExe).toMatch(/write-cred\.exe$/);
  });

  it('respects STUDIO_DIR env var', () => {
    process.env.STUDIO_DIR = '/opt/studio';

    const config = resolveLinuxConfig();
    expect(config.studioDir).toBe('/opt/studio');
    expect(config.studioExe).toBe('/opt/studio/RobloxStudioBeta.exe');
    expect(config.pluginsDir).toBe('/opt/studio/Plugins');
  });

  it('respects WINEPREFIX env var', () => {
    process.env.WINEPREFIX = '/tmp/test-wine';

    const config = resolveLinuxConfig();
    expect(config.winePrefix).toBe('/tmp/test-wine');
  });

  it('respects DISPLAY env var', () => {
    process.env.DISPLAY = ':42';

    const config = resolveLinuxConfig();
    expect(config.display).toBe(':42');
  });
});

describe('STUDIO_PACKAGES', () => {
  it('has 34 package entries', () => {
    expect(Object.keys(STUDIO_PACKAGES)).toHaveLength(34);
  });

  it('includes critical packages', () => {
    expect(STUDIO_PACKAGES).toHaveProperty('RobloxStudio.zip');
    expect(STUDIO_PACKAGES).toHaveProperty('shaders.zip');
    expect(STUDIO_PACKAGES).toHaveProperty('Libraries.zip');
    expect(STUDIO_PACKAGES).toHaveProperty('content-fonts.zip');
  });

  it('maps shaders.zip to shaders/ directory', () => {
    expect(STUDIO_PACKAGES['shaders.zip']).toBe('shaders/');
  });
});
