import { describe, it, expect, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { hashPluginPackageAsync } from './plugin-build-version.js';

describe('hashPluginPackageAsync', () => {
  const dirs: string[] = [];

  afterEach(async () => {
    for (const dir of dirs) {
      await fs.rm(dir, { recursive: true, force: true });
    }
    dirs.length = 0;
  });

  async function makePackageAsync(
    files: Record<string, string>
  ): Promise<string> {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'sb-plugin-'));
    dirs.push(dir);
    const allFiles: Record<string, string> = {
      'package.json': '{}',
      ...files,
    };
    for (const [name, contents] of Object.entries(allFiles)) {
      await fs.mkdir(path.dirname(path.join(dir, name)), { recursive: true });
      await fs.writeFile(path.join(dir, name), contents);
    }
    return dir;
  }

  it('changes when plugin source changes', async () => {
    const before = await makePackageAsync({ 'src/Plugin.lua': 'print(1)' });
    const after = await makePackageAsync({ 'src/Plugin.lua': 'print(2)' });

    expect(await hashPluginPackageAsync(before)).not.toBe(
      await hashPluginPackageAsync(after)
    );
  });

  it('ignores specs, the Jest config and line endings', async () => {
    const plain = await makePackageAsync({ 'src/Plugin.lua': 'a\nb\n' });
    const withTests = await makePackageAsync({
      'src/Plugin.lua': 'a\r\nb\r\n',
      'src/Plugin.spec.lua': 'test',
      'src/jest.config.lua': 'return {}',
    });

    expect(await hashPluginPackageAsync(plain)).toBe(
      await hashPluginPackageAsync(withTests)
    );
  });

  it('changes when a runtime dependency changes, but not a dev dependency', async () => {
    const files = {
      'package.json': JSON.stringify({
        dependencies: { dep: '1' },
        devDependencies: { devdep: '1' },
      }),
      'src/Plugin.lua': 'print(1)',
      'node_modules/devdep/src/Dev.lua': 'print(1)',
    };
    const before = await makePackageAsync({
      ...files,
      'node_modules/dep/src/Dep.lua': 'print(1)',
    });
    const after = await makePackageAsync({
      ...files,
      'node_modules/dep/src/Dep.lua': 'print(2)',
    });
    const devChanged = await makePackageAsync({
      ...files,
      'node_modules/dep/src/Dep.lua': 'print(1)',
      'node_modules/devdep/src/Dev.lua': 'print(2)',
    });

    expect(await hashPluginPackageAsync(before)).not.toBe(
      await hashPluginPackageAsync(after)
    );
    expect(await hashPluginPackageAsync(before)).toBe(
      await hashPluginPackageAsync(devChanged)
    );
  });

  it('is a short hex string', async () => {
    const dir = await makePackageAsync({ 'src/Plugin.lua': 'print(1)' });

    expect(await hashPluginPackageAsync(dir)).toMatch(/^[0-9a-f]{12}$/);
  });
});
