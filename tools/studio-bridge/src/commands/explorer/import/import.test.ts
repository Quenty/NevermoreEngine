import { describe, it, expect, vi, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { importInstancesHandlerAsync } from './import.js';

describe('importInstancesHandlerAsync', () => {
  const dirs: string[] = [];

  afterEach(async () => {
    for (const dir of dirs) {
      await fs.rm(dir, { recursive: true, force: true });
    }
    dirs.length = 0;
  });

  async function writeModelAsync(contents: string): Promise<string> {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'sb-import-'));
    dirs.push(dir);
    const file = path.join(dir, 'model.rbxm');
    await fs.writeFile(file, contents);
    return file;
  }

  function createSession() {
    return {
      importInstancesAsync: vi
        .fn()
        .mockResolvedValue({ paths: ['Workspace.Map'] }),
    } as any;
  }

  it('sends the file as base64 under Workspace by default', async () => {
    const file = await writeModelAsync('<roblox!model');
    const session = createSession();

    const result = await importInstancesHandlerAsync(session, { file });

    expect(session.importInstancesAsync).toHaveBeenCalledWith(
      Buffer.from('<roblox!model').toString('base64'),
      'Workspace'
    );
    expect(result.paths).toEqual(['Workspace.Map']);
  });

  it('uses the given parent', async () => {
    const file = await writeModelAsync('<roblox!model');
    const session = createSession();

    await importInstancesHandlerAsync(session, {
      file,
      parent: 'ServerStorage',
    });

    expect(session.importInstancesAsync).toHaveBeenCalledWith(
      expect.any(String),
      'ServerStorage'
    );
  });
});
