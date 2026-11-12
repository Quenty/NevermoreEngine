import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  findStudioLaunch,
  readStudioLaunchesAsync,
  recordStudioLaunchAsync,
} from './studio-launch-registry.js';

describe('studio launch registry', () => {
  let dir: string;
  let file: string;

  beforeEach(async () => {
    dir = await fs.mkdtemp(path.join(os.tmpdir(), 'launch-registry-'));
    file = path.join(dir, 'nested', 'launches.json');
  });

  afterEach(async () => {
    await fs.rm(dir, { recursive: true, force: true });
  });

  it('records launches and reads them back', async () => {
    await recordStudioLaunchAsync(
      { pid: 10, cwd: '/game', opened: 'a new Baseplate', launchedAt: 1 },
      file
    );

    expect(await readStudioLaunchesAsync(file)).toEqual([
      { pid: 10, cwd: '/game', opened: 'a new Baseplate', launchedAt: 1 },
    ]);
  });

  it('reads a missing or broken registry as empty', async () => {
    expect(await readStudioLaunchesAsync(file)).toEqual([]);
    await fs.mkdir(path.dirname(file), { recursive: true });
    await fs.writeFile(file, 'not json');
    expect(await readStudioLaunchesAsync(file)).toEqual([]);
  });

  it('finds a launch by pid, else by when the process started', () => {
    const records = [
      { pid: 10, cwd: '/a', opened: 'x', launchedAt: 1_000 },
      { cwd: '/b', opened: 'y', launchedAt: 60_000 },
    ];

    expect(findStudioLaunch(records, { pid: 10 })?.cwd).toBe('/a');
    expect(findStudioLaunch(records, { pid: 99, startedAt: 62_000 })?.cwd).toBe(
      '/b'
    );
    expect(
      findStudioLaunch(records, { pid: 99, startedAt: 500_000 })
    ).toBeUndefined();
  });
});
