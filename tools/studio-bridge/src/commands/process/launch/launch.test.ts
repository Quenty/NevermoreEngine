/**
 * Unit tests for the launch command handler.
 */

import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { afterEach, beforeEach, describe, it, expect, vi } from 'vitest';

// Mock the process manager before importing the handler
vi.mock('../../../process/studio-process-manager.js', () => ({
  launchStudioAsync: vi.fn().mockResolvedValue({
    process: {},
    killAsync: vi.fn(),
  }),
}));

import { launchHandlerAsync } from './launch.js';
import { launchStudioAsync } from '../../../process/studio-process-manager.js';

let tempDir: string;

beforeEach(async () => {
  tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'launch-test-'));
  vi.mocked(launchStudioAsync).mockClear();
});

afterEach(async () => {
  await fs.rm(tempDir, { recursive: true, force: true });
});

async function writeDeployConfigAsync(dir: string, config: unknown) {
  await fs.writeFile(
    path.join(dir, 'deploy.nevermore.json'),
    JSON.stringify(config)
  );
}

const place = (placeId: number, name?: string) => ({
  name,
  universeId: 900,
  placeId,
  project: 'default.project.json',
});

describe('launchHandlerAsync', () => {
  it('launches a bare Studio outside any deploy.nevermore.json', async () => {
    const result = await launchHandlerAsync({ cwd: tempDir });

    expect(launchStudioAsync).toHaveBeenCalledWith({});
    expect(result.launched).toBe(true);
    expect(result.summary).toBe('Studio launched');
  });

  it('passes place path to launchStudioAsync', async () => {
    const result = await launchHandlerAsync({
      placePath: '/tmp/game.rbxl',
      cwd: tempDir,
    });

    expect(launchStudioAsync).toHaveBeenCalledWith({
      placePath: '/tmp/game.rbxl',
    });
    expect(result.summary).toBe('Studio launched with /tmp/game.rbxl');
  });

  it('passes cloud place + universe ids to launchStudioAsync', async () => {
    const result = await launchHandlerAsync({
      placeId: 84760113521251,
      universeId: 9893751595,
      cwd: tempDir,
    });

    expect(launchStudioAsync).toHaveBeenCalledWith({
      placeId: 84760113521251,
      universeId: 9893751595,
    });
    expect(result.summary).toBe(
      'Studio launched with place 84760113521251 (universe 9893751595)'
    );
  });

  it('summarizes a cloud place id without a universe id', async () => {
    const result = await launchHandlerAsync({ placeId: 123, cwd: tempDir });

    expect(result.summary).toBe('Studio launched with place 123');
  });

  it('propagates errors from launchStudioAsync', async () => {
    vi.mocked(launchStudioAsync).mockRejectedValueOnce(
      new Error('Studio not found')
    );

    await expect(launchHandlerAsync({ cwd: tempDir })).rejects.toThrow(
      'Studio not found'
    );
  });
});

describe('launchHandlerAsync with deploy.nevermore.json', () => {
  it("opens the default target's place from a parent directory's config", async () => {
    await writeDeployConfigAsync(tempDir, { targets: { test: place(111) } });
    const nested = path.join(tempDir, 'src', 'Server');
    await fs.mkdir(nested, { recursive: true });

    const result = await launchHandlerAsync({ cwd: nested });

    expect(launchStudioAsync).toHaveBeenCalledWith({
      placeId: 111,
      universeId: 900,
    });
    expect(result).toMatchObject({
      deployTarget: 'test',
      placeId: 111,
      universeId: 900,
    });
    expect(result.summary).toBe(
      `Studio launched with 'test' (place 111, universe 900) from ${path.join(
        '..',
        '..',
        'deploy.nevermore.json'
      )}`
    );
  });

  it('opens a named target and narrows to one of its places', async () => {
    await writeDeployConfigAsync(tempDir, {
      targets: {
        test: place(111),
        integration: { places: [place(222, 'hub'), place(333, 'arena')] },
      },
    });

    const result = await launchHandlerAsync({
      deployTarget: 'integration.places.arena',
      cwd: tempDir,
    });

    expect(launchStudioAsync).toHaveBeenCalledWith({
      placeId: 333,
      universeId: 900,
    });
    expect(result.deployTarget).toBe('integration.places.arena');
  });

  it('asks which place to open for a target with several', async () => {
    await writeDeployConfigAsync(tempDir, {
      targets: {
        integration: { places: [place(222, 'hub'), place(333, 'arena')] },
      },
    });

    await expect(
      launchHandlerAsync({ deployTarget: 'integration', cwd: tempDir })
    ).rejects.toThrow(
      "Target 'integration' has 2 places. Pick one:\n  - integration.places.hub\n  - integration.places.arena"
    );
    expect(launchStudioAsync).not.toHaveBeenCalled();
  });

  it('skips a config without targets, like a repo root universe id', async () => {
    await writeDeployConfigAsync(tempDir, { universeId: 900 });

    const result = await launchHandlerAsync({ cwd: tempDir });

    expect(launchStudioAsync).toHaveBeenCalledWith({});
    expect(result.summary).toBe('Studio launched');
  });

  it('asks for a target when the config has no default', async () => {
    await writeDeployConfigAsync(tempDir, {
      targets: { alpha: place(1), beta: place(2) },
    });

    await expect(launchHandlerAsync({ cwd: tempDir })).rejects.toThrow(
      'has several targets and no default. Name one: alpha, beta'
    );
  });

  it('fails on a target when no deploy.nevermore.json is found', async () => {
    await expect(
      launchHandlerAsync({ deployTarget: 'test', cwd: tempDir })
    ).rejects.toThrow(/No deploy.nevermore.json in .* to find target 'test'/);
  });

  it('refuses a target together with --place', async () => {
    await expect(
      launchHandlerAsync({
        deployTarget: 'test',
        placePath: '/tmp/game.rbxl',
        cwd: tempDir,
      })
    ).rejects.toThrow('not both');
  });

  it('prefers an explicit --place over the config', async () => {
    await writeDeployConfigAsync(tempDir, { targets: { test: place(111) } });

    await launchHandlerAsync({ placePath: '/tmp/game.rbxl', cwd: tempDir });

    expect(launchStudioAsync).toHaveBeenCalledWith({
      placePath: '/tmp/game.rbxl',
    });
  });
});
