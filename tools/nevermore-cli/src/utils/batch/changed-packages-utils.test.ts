import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  discoverAllTargetPackagesAsync,
  discoverChangedTargetPackagesAsync,
} from './changed-packages-utils.js';

vi.mock('execa', () => ({ execa: vi.fn() }));
vi.mock('fs/promises', async (importOriginal) => {
  const actual = await importOriginal<typeof import('fs/promises')>();
  return { ...actual, readFile: vi.fn(actual.readFile) };
});

const target = { universeId: 1, placeId: 2, project: 'default.project.json' };

describe.each(['all', 'changed'] as const)('%s target discovery', (mode) => {
  let root: string;
  let packages: Array<{ name: string; path: string }>;

  beforeEach(async () => {
    const actual = await vi.importActual<typeof import('fs/promises')>(
      'fs/promises'
    );
    vi.mocked(fs.readFile).mockImplementation(actual.readFile);
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'nevermore-discovery-'));
    packages = [];
    vi.spyOn(OutputHelper, 'verbose').mockImplementation(() => {});
    vi.mocked(execa).mockImplementation((async () => ({
      stdout: JSON.stringify(packages),
    })) as any);
  });

  afterEach(async () => {
    vi.restoreAllMocks();
    vi.mocked(execa).mockReset();
    await fs.rm(root, { recursive: true, force: true });
  });

  const discover = (selector = 'test') =>
    mode === 'all'
      ? discoverAllTargetPackagesAsync(selector)
      : discoverChangedTargetPackagesAsync('origin/main', selector);

  async function addPackage(name: string, contents?: string) {
    const directory = path.join(root, name);
    await fs.mkdir(directory);
    packages.push({ name, path: directory });
    const configPath = path.join(directory, 'deploy.nevermore.json');
    if (contents !== undefined) await fs.writeFile(configPath, contents);
    return configPath;
  }

  it('discovers valid packages while skipping absent configs and targets', async () => {
    await addPackage('no-config');
    await addPackage(
      'other-target',
      JSON.stringify({ targets: { prod: target } })
    );
    await addPackage('valid', JSON.stringify({ targets: { test: target } }));

    expect(await discover()).toEqual([
      {
        name: 'valid',
        path: path.join(root, 'valid'),
        activeTargets: [target],
      },
    ]);
  });

  it('preserves multi-place targets and skips packages without the selected place', async () => {
    const hub = { ...target, name: 'hub' };
    const lobby = { ...target, name: 'lobby', placeId: 3 };
    await addPackage(
      'multi',
      JSON.stringify({ targets: { test: { places: [hub, lobby] } } })
    );
    await addPackage(
      'other-place',
      JSON.stringify({ targets: { test: lobby } })
    );

    expect((await discover())[0].activeTargets).toEqual([hub, lobby]);
    expect(
      (await discover('test.places.hub')).map((pkg) => pkg.activeTargets)
    ).toEqual([[hub]]);
  });

  it.each([
    ['malformed JSON', '{ invalid'],
    ['missing targets', '{}'],
    [
      'invalid target',
      JSON.stringify({ targets: { test: { ...target, universeId: 'wrong' } } }),
    ],
    [
      'empty multi-place target',
      JSON.stringify({ targets: { test: { places: [] } } }),
    ],
    ['null target', JSON.stringify({ targets: { test: null } })],
  ])(
    'rejects %s even when a valid package is discovered first',
    async (_label, contents) => {
      await addPackage('valid', JSON.stringify({ targets: { test: target } }));
      const configPath = await addPackage('broken', contents);

      await expect(discover()).rejects.toThrow(configPath);
      await expect(discover()).rejects.toThrow('broken');
    }
  );

  it('keeps the original validation diagnostic as the error cause', async () => {
    await addPackage(
      'broken',
      JSON.stringify({ targets: { test: { ...target, universeId: 'wrong' } } })
    );
    const error = await discover().catch((err: unknown) => err);
    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toContain('universeId');
    expect((error as Error).cause).toBeInstanceOf(Error);
  });

  it('rejects an unreadable config rather than treating it as absent', async () => {
    const configPath = await addPackage('directory');
    await fs.mkdir(configPath);
    await expect(discover()).rejects.toThrow(configPath);
  });

  it('preserves permission errors rather than claiming the config is missing', async () => {
    const configPath = await addPackage(
      'denied',
      JSON.stringify({ targets: { test: target } })
    );
    const denied = Object.assign(new Error('Permission denied'), {
      code: 'EACCES',
    });
    vi.mocked(fs.readFile).mockRejectedValueOnce(denied);
    const error = await discover().catch((err: unknown) => err);
    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toContain(configPath);
    expect((error as Error).message).toContain('Permission denied');
    expect((error as Error).message).not.toContain('not found');
  });

  it.each(['', '.places.hub', 'test.places.'])(
    'rejects invalid selector %j in an empty workspace',
    async (selector) => {
      await expect(discover(selector)).rejects.toThrow(/selector/i);
      expect(execa).not.toHaveBeenCalled();
    }
  );

  it('returns an empty list for a valid selector in an empty workspace', async () => {
    expect(await discover()).toEqual([]);
  });
});
