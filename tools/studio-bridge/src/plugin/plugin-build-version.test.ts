import { describe, it, expect, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { hashTemplateDirAsync } from './plugin-build-version.js';

describe('hashTemplateDirAsync', () => {
  const dirs: string[] = [];

  afterEach(async () => {
    for (const dir of dirs) {
      await fs.rm(dir, { recursive: true, force: true });
    }
    dirs.length = 0;
  });

  async function makeTemplateAsync(
    files: Record<string, string>
  ): Promise<string> {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'sb-template-'));
    dirs.push(dir);
    for (const [name, contents] of Object.entries(files)) {
      await fs.mkdir(path.dirname(path.join(dir, name)), { recursive: true });
      await fs.writeFile(path.join(dir, name), contents);
    }
    return dir;
  }

  it('changes when plugin source changes', async () => {
    const before = await makeTemplateAsync({ 'src/Plugin.lua': 'print(1)' });
    const after = await makeTemplateAsync({ 'src/Plugin.lua': 'print(2)' });

    expect(await hashTemplateDirAsync(before)).not.toBe(
      await hashTemplateDirAsync(after)
    );
  });

  it('ignores specs and line endings', async () => {
    const plain = await makeTemplateAsync({ 'src/Plugin.lua': 'a\nb\n' });
    const withSpec = await makeTemplateAsync({
      'src/Plugin.lua': 'a\r\nb\r\n',
      'src/Plugin.spec.lua': 'test',
    });

    expect(await hashTemplateDirAsync(plain)).toBe(
      await hashTemplateDirAsync(withSpec)
    );
  });

  it('is a short hex string', async () => {
    const dir = await makeTemplateAsync({ 'src/Plugin.lua': 'print(1)' });

    expect(await hashTemplateDirAsync(dir)).toMatch(/^[0-9a-f]{12}$/);
  });
});
