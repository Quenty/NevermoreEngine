import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import {
  DeployTargetsMissingError,
  discoverUniverseIdAsync,
  loadDeployConfigAsync,
} from './deploy-config.js';

describe('metadata-only deploy configs', () => {
  let root: string;
  let configPath: string;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'nevermore-metadata-'));
    configPath = path.join(root, 'deploy.nevermore.json');
  });

  afterEach(async () => {
    await fs.rm(root, { recursive: true, force: true });
  });

  it('keeps explicit deployment loading strict and identifies omitted targets', async () => {
    await fs.writeFile(configPath, JSON.stringify({ universeId: 9716264427 }));
    await expect(loadDeployConfigAsync(configPath)).rejects.toThrowError(
      DeployTargetsMissingError
    );
    await expect(loadDeployConfigAsync(configPath)).rejects.toThrowError(
      /missing "targets" field/
    );
  });

  it.each([null, [], false, 'test'])(
    'does not classify declared targets %j as metadata-only',
    async (targets) => {
      await fs.writeFile(configPath, JSON.stringify({ targets }));
      const error = await loadDeployConfigAsync(configPath).catch(
        (err: unknown) => err
      );
      expect(error).toBeInstanceOf(Error);
      expect(error).not.toBeInstanceOf(DeployTargetsMissingError);
      expect((error as Error).message).toContain('invalid "targets"');
    }
  );

  it.each([null, []])(
    'does not classify a non-object config %j as metadata-only',
    async (config) => {
      await fs.writeFile(configPath, JSON.stringify(config));
      const error = await loadDeployConfigAsync(configPath).catch(
        (err: unknown) => err
      );
      expect(error).toBeInstanceOf(Error);
      expect(error).not.toBeInstanceOf(DeployTargetsMissingError);
    }
  );

  it('still discovers the seeded universe from a child without deploy targets', async () => {
    await fs.writeFile(configPath, JSON.stringify({ universeId: 9716264427 }));
    const child = path.join(root, 'child');
    await fs.mkdir(child);
    expect(await discoverUniverseIdAsync(child)).toBe(9716264427);
  });

  it('retains support for an explicitly empty targets map', async () => {
    await fs.writeFile(configPath, JSON.stringify({ targets: {} }));
    expect(await loadDeployConfigAsync(configPath)).toEqual({ targets: {} });
  });
});
