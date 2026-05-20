import { describe, it, expect, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { writeFflagsAsync } from './linux-fflags.js';
import type { LinuxStudioConfig } from './linux-config.js';

describe('writeFflagsAsync', () => {
  let tmpDir: string;

  afterEach(async () => {
    if (tmpDir) {
      await fs.rm(tmpDir, { recursive: true, force: true });
    }
  });

  function makeConfig(): LinuxStudioConfig {
    const clientSettingsPath = path.join(
      tmpDir,
      'ClientSettings',
      'ClientAppSettings.json'
    );
    return {
      studioDir: tmpDir,
      winePrefix: '/tmp/fake-wine',
      display: ':99',
      studioExe: path.join(tmpDir, 'RobloxStudioBeta.exe'),
      clientSettingsPath,
      shadersDir: path.join(tmpDir, 'shaders'),
      pluginsDir: path.join(tmpDir, 'Plugins'),
      writeCredExe: path.join(tmpDir, 'write-cred.exe'),
    };
  }

  it('writes valid JSON with all 5 required FFlags', async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'fflags-test-'));
    const config = makeConfig();

    await writeFflagsAsync(config);

    const content = JSON.parse(
      await fs.readFile(config.clientSettingsPath, 'utf-8')
    );
    expect(content.FFlagDebugGraphicsPreferD3D11).toBe(true);
    expect(content.FFlagDebugGraphicsDisableVulkan).toBe(true);
    expect(content.FFlagDebugGraphicsDisableD3D11FL10).toBe(true);
    expect(content.FFlagDebugGraphicsDisableOpenGL).toBe(true);
    expect(content.FIntStudioLowMemoryThresholdPercentage).toBe(0);
  });

  it('creates parent directories', async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'fflags-test-'));
    const config = makeConfig();

    // Directory shouldn't exist yet
    await expect(
      fs.access(path.dirname(config.clientSettingsPath))
    ).rejects.toThrow();

    await writeFflagsAsync(config);

    // Now it should
    await fs.access(path.dirname(config.clientSettingsPath));
  });

  it('merges extra flags without dropping defaults', async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'fflags-test-'));
    const config = makeConfig();

    await writeFflagsAsync(config, { FIntCustomFlag: 42 });

    const content = JSON.parse(
      await fs.readFile(config.clientSettingsPath, 'utf-8')
    );
    expect(content.FIntCustomFlag).toBe(42);
    expect(content.FFlagDebugGraphicsPreferD3D11).toBe(true);
  });
});
