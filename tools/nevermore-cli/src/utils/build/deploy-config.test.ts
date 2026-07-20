import { describe, it, expect } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import {
  type DeployConfig,
  type DeployTarget,
  loadDeployConfigAsync,
  resolveDefaultTargetName,
} from './deploy-config.js';

async function writeTempConfigAsync(config: unknown): Promise<string> {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'deploy-config-test-'));
  const configPath = path.join(dir, 'deploy.nevermore.json');
  await fs.writeFile(configPath, JSON.stringify(config));
  return configPath;
}

function makeTarget(placeId: number): DeployTarget {
  return {
    universeId: 1,
    placeId,
    project: 'default.project.json',
  };
}

function makeConfig(targets: Record<string, DeployTarget>): DeployConfig {
  return { targets };
}

describe('resolveDefaultTargetName', () => {
  it('returns the only target when there is just one', () => {
    const config = makeConfig({ prod: makeTarget(1) });
    expect(resolveDefaultTargetName(config)).toBe('prod');
  });

  it('prefers integration over test when both exist', () => {
    const config = makeConfig({
      test: makeTarget(1),
      integration: makeTarget(2),
    });
    expect(resolveDefaultTargetName(config)).toBe('integration');
  });

  it('falls back to test when integration is absent', () => {
    const config = makeConfig({ test: makeTarget(1), dev: makeTarget(2) });
    expect(resolveDefaultTargetName(config)).toBe('test');
  });

  it('returns integration when present alongside non-test targets', () => {
    const config = makeConfig({
      integration: makeTarget(1),
      dev: makeTarget(2),
    });
    expect(resolveDefaultTargetName(config)).toBe('integration');
  });

  it('throws when no preferred target exists and multiple options are present', () => {
    const config = makeConfig({ foo: makeTarget(1), bar: makeTarget(2) });
    expect(() => resolveDefaultTargetName(config)).toThrowError(/foo, bar/);
  });
});

describe('loadDeployConfigAsync basePlace.version', () => {
  it('accepts an omitted version pin', async () => {
    const configPath = await writeTempConfigAsync({
      targets: {
        test: {
          universeId: 1,
          placeId: 2,
          project: 'default.project.json',
          basePlace: { universeId: 1, placeId: 3 },
        },
      },
    });
    const config = await loadDeployConfigAsync(configPath);
    const target = config.targets['test'] as DeployTarget;
    expect(target.basePlace?.version).toBeUndefined();
  });

  it('accepts a positive integer version pin', async () => {
    const configPath = await writeTempConfigAsync({
      targets: {
        test: {
          universeId: 1,
          placeId: 2,
          project: 'default.project.json',
          basePlace: { universeId: 1, placeId: 3, version: 42 },
        },
      },
    });
    const config = await loadDeployConfigAsync(configPath);
    const target = config.targets['test'] as DeployTarget;
    expect(target.basePlace?.version).toBe(42);
  });

  it('rejects a non-integer version pin', async () => {
    const configPath = await writeTempConfigAsync({
      targets: {
        test: {
          universeId: 1,
          placeId: 2,
          project: 'default.project.json',
          basePlace: { universeId: 1, placeId: 3, version: 1.5 },
        },
      },
    });
    await expect(loadDeployConfigAsync(configPath)).rejects.toThrowError(
      /version.*positive integer/
    );
  });

  it('rejects a zero or negative version pin', async () => {
    const configPath = await writeTempConfigAsync({
      targets: {
        test: {
          universeId: 1,
          placeId: 2,
          project: 'default.project.json',
          basePlace: { universeId: 1, placeId: 3, version: 0 },
        },
      },
    });
    await expect(loadDeployConfigAsync(configPath)).rejects.toThrowError(
      /version.*positive integer/
    );
  });

  it('validates version pins on multi-place targets too', async () => {
    const configPath = await writeTempConfigAsync({
      targets: {
        prod: {
          places: [
            {
              name: 'chapter0',
              universeId: 1,
              placeId: 2,
              project: 'default.project.json',
              basePlace: { universeId: 1, placeId: 3, version: -1 },
            },
          ],
        },
      },
    });
    await expect(loadDeployConfigAsync(configPath)).rejects.toThrowError(
      /chapter0.*version.*positive integer/
    );
  });
});
