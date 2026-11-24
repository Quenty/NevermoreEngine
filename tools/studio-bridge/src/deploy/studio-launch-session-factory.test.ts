import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const state = vi.hoisted(() => ({ dir: '' }));
vi.mock('../state-dir.js', () => ({ getStateDir: () => state.dir }));
vi.mock('../process/launch-and-record-studio.js', () => ({
  launchAndRecordStudioAsync: vi.fn().mockResolvedValue(undefined),
}));
// The identity transform writes the marked copy; a plain copy stands in for it.
vi.mock('execa', () => ({
  execa: vi.fn(async (_command: string, args: string[]) => {
    const { copyFile } = await import('fs/promises');
    await copyFile(args[2], args[3]);
    return {};
  }),
}));

import { execa } from 'execa';
import { launchAndRecordStudioAsync } from '../process/launch-and-record-studio.js';
import {
  createStudioLaunchSessionFactory,
  pruneBuiltPlacesAsync,
} from './studio-launch-session-factory.js';

const DAY_MS = 24 * 60 * 60 * 1000;
const IDENTITY = { placeId: 111, universeId: 900 };

let root: string;

beforeEach(async () => {
  root = await fs.mkdtemp(path.join(os.tmpdir(), 'built-places-test-'));
  state.dir = path.join(root, 'state');
  vi.mocked(launchAndRecordStudioAsync).mockClear();
  vi.mocked(execa).mockClear();
});

afterEach(async () => {
  await fs.rm(root, { recursive: true, force: true });
});

async function makeBuildAsync(name: string): Promise<string> {
  const dir = path.join(root, name);
  await fs.mkdir(dir);
  await fs.writeFile(path.join(dir, 'test.rbxl'), 'place');
  return dir;
}

async function existsAsync(dir: string): Promise<boolean> {
  return fs
    .access(dir)
    .then(() => true)
    .catch(() => false);
}

describe('pruneBuiltPlacesAsync', () => {
  it('deletes a build whose Studio has closed and keeps one still open', async () => {
    const closed = await makeBuildAsync('closed');
    const open = await makeBuildAsync('open');

    await pruneBuiltPlacesAsync({
      root,
      getStateAsync: async (dir) => (dir === open ? 'open' : 'closed'),
    });

    expect(await existsAsync(closed)).toBe(false);
    expect(await existsAsync(open)).toBe(true);
  });

  it('keeps a build whose Studio is still open, however old', async () => {
    const open = await makeBuildAsync('open');

    await pruneBuiltPlacesAsync({
      root,
      now: Date.now() + 2 * DAY_MS,
      getStateAsync: async () => 'open',
    });

    expect(await existsAsync(open)).toBe(true);
  });

  it('keeps an unidentified build for a day, then deletes it', async () => {
    const build = await makeBuildAsync('unidentified');

    await pruneBuiltPlacesAsync({ root, getStateAsync: async () => 'unknown' });
    expect(await existsAsync(build)).toBe(true);

    await pruneBuiltPlacesAsync({
      root,
      now: Date.now() + 2 * DAY_MS,
      getStateAsync: async () => 'unknown',
    });
    expect(await existsAsync(build)).toBe(false);
  });

  it('does nothing when no build has been made yet', async () => {
    await expect(
      pruneBuiltPlacesAsync({ root: path.join(root, 'missing') })
    ).resolves.toBeUndefined();
  });
});

describe('createStudioLaunchSessionFactory', () => {
  async function makeTempBuildAsync(): Promise<string> {
    const placePath = path.join(root, 'build.rbxl');
    await fs.writeFile(placePath, 'place');
    return placePath;
  }

  it('launches Studio on a copy in the state dir, and records it', async () => {
    const placePath = await makeTempBuildAsync();
    const onPhase = vi.fn();

    const session = await createStudioLaunchSessionFactory({
      selector: 'integration.places.hub',
      cwd: '/repo/games/integration',
      placeIdentity: IDENTITY,
    }).startSessionAsync({ placePath, onPhase });

    expect(session.stateDir).toBeDefined();
    expect(path.dirname(session.stateDir!)).toBe(
      path.join(state.dir, 'places')
    );
    expect(session.placePath).toBe(
      path.join(session.stateDir!, 'integration.places.hub.rbxl')
    );
    expect(await fs.readFile(session.placePath, 'utf8')).toBe('place');
    expect(onPhase).toHaveBeenCalledWith('launching');
    expect(launchAndRecordStudioAsync).toHaveBeenCalledWith(
      { placePath: session.placePath },
      {
        opened: "'integration.places.hub' (local build)",
        deployTarget: 'integration.places.hub',
        placeDir: session.stateDir,
      },
      '/repo/games/integration'
    );
  });

  it('marks the copy with the target identity for the plugin to apply', async () => {
    const placePath = await makeTempBuildAsync();

    const session = await createStudioLaunchSessionFactory({
      selector: 'hub',
      placeIdentity: IDENTITY,
    }).startSessionAsync({ placePath });

    expect(execa).toHaveBeenCalledWith('lune', [
      'run',
      expect.stringMatching(/transform-add-place-identity\.lua$/),
      placePath,
      session.placePath,
      '111',
      '900',
    ]);
    expect(launchAndRecordStudioAsync).toHaveBeenCalledWith(
      { placePath: session.placePath },
      expect.anything(),
      undefined
    );
  });

  it('leaves Studio and its copy alone when the session ends', async () => {
    const placePath = await makeTempBuildAsync();
    const session = await createStudioLaunchSessionFactory({
      selector: 'hub',
      placeIdentity: IDENTITY,
    }).startSessionAsync({ placePath });

    await session.endAsync();

    expect(await existsAsync(session.placePath)).toBe(true);
    expect(launchAndRecordStudioAsync).toHaveBeenCalledTimes(1);
  });

  it('removes its copy when Studio fails to launch', async () => {
    const placePath = await makeTempBuildAsync();
    vi.mocked(launchAndRecordStudioAsync).mockRejectedValueOnce(
      new Error('Studio is not installed')
    );

    await expect(
      createStudioLaunchSessionFactory({
        selector: 'hub',
        placeIdentity: IDENTITY,
      }).startSessionAsync({
        placePath,
      })
    ).rejects.toThrow('Studio is not installed');
    expect(await fs.readdir(path.join(state.dir, 'places'))).toEqual([]);
  });
});
