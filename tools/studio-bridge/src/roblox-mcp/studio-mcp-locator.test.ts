import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  findStudioMcpLaunchAsync,
  parseContentFolder,
} from './studio-mcp-locator.js';

describe('findStudioMcpLaunchAsync', () => {
  let localAppData: string;
  let versionsDir: string;

  beforeEach(async () => {
    localAppData = await fs.mkdtemp(path.join(os.tmpdir(), 'studio-mcp-'));
    versionsDir = path.join(localAppData, 'Roblox', 'Versions');
    await fs.mkdir(versionsDir, { recursive: true });
  });

  afterEach(async () => {
    await fs.rm(localAppData, { recursive: true, force: true });
  });

  async function makeVersionAsync(
    name: string,
    files: string[],
    mtime: Date
  ): Promise<string> {
    const dir = path.join(versionsDir, name);
    await fs.mkdir(path.join(dir, 'content'), { recursive: true });
    for (const file of files) {
      await fs.writeFile(path.join(dir, file), '');
    }
    await fs.utimes(dir, mtime, mtime);
    return dir;
  }

  it('uses the version folder the registry content folder is in', async () => {
    const dir = await makeVersionAsync(
      'version-current',
      ['RobloxStudioBeta.exe', 'StudioMCP.exe'],
      new Date(2026, 0, 1)
    );
    await makeVersionAsync(
      'version-newer',
      ['RobloxStudioBeta.exe', 'StudioMCP.exe'],
      new Date(2026, 5, 1)
    );

    const { command: found } = await findStudioMcpLaunchAsync({
      platform: 'win32',
      localAppData,
      readContentFolderAsync: async () => path.join(dir, 'content') + path.sep,
    });

    expect(found).toBe(path.join(dir, 'StudioMCP.exe'));
  });

  it('skips a registry folder that only holds a lingering StudioMCP.exe', async () => {
    const stale = await makeVersionAsync(
      'version-stale',
      ['StudioMCP.exe'],
      new Date(2026, 5, 1)
    );
    const current = await makeVersionAsync(
      'version-current',
      ['RobloxStudioBeta.exe', 'StudioMCP.exe'],
      new Date(2026, 0, 1)
    );

    const { command: found } = await findStudioMcpLaunchAsync({
      platform: 'win32',
      localAppData,
      readContentFolderAsync: async () => path.join(stale, 'content'),
    });

    expect(found).toBe(path.join(current, 'StudioMCP.exe'));
  });

  it('falls back to the newest folder holding both executables', async () => {
    await makeVersionAsync(
      'version-old',
      ['RobloxStudioBeta.exe', 'StudioMCP.exe'],
      new Date(2026, 0, 1)
    );
    const newest = await makeVersionAsync(
      'version-new',
      ['RobloxStudioBeta.exe', 'StudioMCP.exe'],
      new Date(2026, 3, 1)
    );
    await makeVersionAsync(
      'version-newest-stale',
      ['StudioMCP.exe'],
      new Date(2026, 6, 1)
    );

    const { command: found } = await findStudioMcpLaunchAsync({
      platform: 'win32',
      localAppData,
      readContentFolderAsync: async () => undefined,
    });

    expect(found).toBe(path.join(newest, 'StudioMCP.exe'));
  });

  it('says so when no folder holds both executables', async () => {
    await makeVersionAsync(
      'version-stale',
      ['StudioMCP.exe'],
      new Date(2026, 0, 1)
    );

    await expect(
      findStudioMcpLaunchAsync({
        platform: 'win32',
        localAppData,
        readContentFolderAsync: async () => undefined,
      })
    ).rejects.toThrow('No StudioMCP.exe found next to RobloxStudioBeta.exe');
  });

  it('finds StudioMCP in the macOS app bundle', async () => {
    const exe = path.join(localAppData, 'StudioMCP');
    await fs.writeFile(exe, '');

    const launch = await findStudioMcpLaunchAsync({
      platform: 'darwin',
      macCandidates: [path.join(localAppData, 'missing'), exe],
    });

    expect(launch).toEqual({ command: exe, args: [] });
  });

  it('runs the Linux StudioMCP.exe under wine with its environment', async () => {
    await fs.writeFile(path.join(localAppData, 'StudioMCP.exe'), '');
    const env = { WINEPREFIX: '/wine' };

    const launch = await findStudioMcpLaunchAsync({
      platform: 'linux',
      linuxStudioDir: localAppData,
      linuxEnv: env,
    });

    expect(launch).toEqual({
      command: 'wine',
      args: [path.join(localAppData, 'StudioMCP.exe')],
      env,
    });
  });

  it('says so when the Linux Studio has no StudioMCP.exe', async () => {
    await expect(
      findStudioMcpLaunchAsync({
        platform: 'linux',
        linuxStudioDir: localAppData,
        linuxEnv: {},
      })
    ).rejects.toThrow('No StudioMCP.exe in');
  });

  it('refuses a platform Studio does not run on', async () => {
    await expect(
      findStudioMcpLaunchAsync({ platform: 'freebsd' })
    ).rejects.toThrow('not available on freebsd');
  });
});

describe('parseContentFolder', () => {
  it('reads the value out of reg query output', () => {
    expect(
      parseContentFolder(
        '\r\nHKEY_CURRENT_USER\\Software\\Roblox\\RobloxStudio\r\n    ContentFolder    REG_SZ    C:\\Users\\a b\\AppData\\Local\\Roblox\\Versions\\version-1\\content\\\r\n\r\n'
      )
    ).toBe(
      'C:\\Users\\a b\\AppData\\Local\\Roblox\\Versions\\version-1\\content\\'
    );
  });

  it('returns undefined when the value is missing', () => {
    expect(
      parseContentFolder(
        'ERROR: The system was unable to find the specified registry key or value.'
      )
    ).toBeUndefined();
  });
});
