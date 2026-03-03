import { describe, it, expect, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { patchShadersAsync } from './linux-shader-patcher.js';
import type { LinuxStudioConfig } from './linux-config.js';

describe('patchShadersAsync', () => {
  let tmpDir: string;

  afterEach(async () => {
    if (tmpDir) {
      await fs.rm(tmpDir, { recursive: true, force: true });
    }
  });

  function makeConfig(): LinuxStudioConfig {
    return {
      studioDir: tmpDir,
      winePrefix: '/tmp/fake-wine',
      display: ':99',
      studioExe: path.join(tmpDir, 'RobloxStudioBeta.exe'),
      clientSettingsPath: path.join(tmpDir, 'ClientSettings', 'ClientAppSettings.json'),
      shadersDir: path.join(tmpDir, 'shaders'),
      pluginsDir: path.join(tmpDir, 'Plugins'),
      writeCredExe: path.join(tmpDir, 'write-cred.exe'),
    };
  }

  async function writeFakeShaderPack(content: Buffer): Promise<void> {
    const dir = path.join(tmpDir, 'shaders');
    await fs.mkdir(dir, { recursive: true });
    await fs.writeFile(path.join(dir, 'shaders_glsl3.pack'), content);
  }

  it('replaces #version 150 with #version 420', async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'shader-test-'));
    const config = makeConfig();

    // Create a fake shader pack with two occurrences
    const data = Buffer.from(
      'header#version 150middle#version 150tail'
    );
    await writeFakeShaderPack(data);

    const count = await patchShadersAsync(config);
    expect(count).toBe(2);

    const patched = await fs.readFile(
      path.join(config.shadersDir, 'shaders_glsl3.pack')
    );
    expect(patched.toString()).toBe(
      'header#version 420middle#version 420tail'
    );
  });

  it('returns 0 on second run (idempotent)', async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'shader-test-'));
    const config = makeConfig();

    await writeFakeShaderPack(Buffer.from('data#version 150end'));

    await patchShadersAsync(config);
    const count = await patchShadersAsync(config);
    expect(count).toBe(0);
  });

  it('throws if shader pack not found', async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'shader-test-'));
    const config = makeConfig();

    await expect(patchShadersAsync(config)).rejects.toThrow(
      'Shader pack not found'
    );
  });
});
