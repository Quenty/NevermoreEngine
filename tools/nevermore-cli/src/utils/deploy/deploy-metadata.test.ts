import { describe, it, expect } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import {
  buildDeployMetadataAttributes,
  packageUsesManifestAsync,
  type GitDeployInfo,
  type DeployPlaceInfo,
} from './deploy-metadata.js';

async function withPackageJsonAsync(
  contents: unknown,
  fn: (dir: string) => Promise<void>
): Promise<void> {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'manifest-gate-'));
  try {
    if (contents !== undefined) {
      await fs.writeFile(
        path.join(dir, 'package.json'),
        JSON.stringify(contents)
      );
    }
    await fn(dir);
  } finally {
    await fs.rm(dir, { recursive: true, force: true });
  }
}

const PLACE: DeployPlaceInfo = {
  target: 'integration',
  published: true,
  timestamp: '2026-07-15T00:00:00.000Z',
  placeId: 123,
  universeId: 456,
};

describe('buildDeployMetadataAttributes', () => {
  it('always marks the build as deployed and includes place info', () => {
    const attributes = buildDeployMetadataAttributes({}, PLACE);
    expect(attributes.Deployed).toBe(true);
    expect(attributes.Target).toBe('integration');
    expect(attributes.Published).toBe(true);
    expect(attributes.Timestamp).toBe('2026-07-15T00:00:00.000Z');
  });

  it('stringifies place/universe IDs so Lune float32 does not corrupt them', () => {
    const attributes = buildDeployMetadataAttributes(
      {},
      {
        ...PLACE,
        placeId: 123456789,
        universeId: 987654321,
      }
    );
    // Must be exact strings — as numbers these round to 123456792 / 987654336.
    expect(attributes.PlaceId).toBe('123456789');
    expect(attributes.UniverseId).toBe('987654321');
  });

  it('includes git fields when present', () => {
    const git: GitDeployInfo = {
      commit: 'a1b2c3d',
      version: 'a1b2c3d4e5f6',
      branch: 'main',
    };
    const attributes = buildDeployMetadataAttributes(git, PLACE);
    expect(attributes.Commit).toBe('a1b2c3d');
    expect(attributes.Version).toBe('a1b2c3d4e5f6');
    expect(attributes.Branch).toBe('main');
  });

  it('omits git fields that are unavailable', () => {
    const attributes = buildDeployMetadataAttributes({}, PLACE);
    expect('Commit' in attributes).toBe(false);
    expect('Version' in attributes).toBe(false);
    expect('Branch' in attributes).toBe(false);
  });

  it('reflects a Saved (unpublished) deploy', () => {
    const attributes = buildDeployMetadataAttributes(
      {},
      { ...PLACE, published: false }
    );
    expect(attributes.Published).toBe(false);
  });

  it('omits Places when no place table is given', () => {
    const attributes = buildDeployMetadataAttributes({}, PLACE);
    expect('Places' in attributes).toBe(false);
  });

  it('stamps Places as a JSON string preserving large IDs exactly', () => {
    const attributes = buildDeployMetadataAttributes({}, PLACE, [
      { name: 'chapter0', placeId: 97235312452456, universeId: 10192566764 },
      { name: 'chapter1', placeId: 87639818897831, universeId: 10192566764 },
    ]);
    expect(typeof attributes.Places).toBe('string');
    const parsed = JSON.parse(attributes.Places as string);
    // Large place IDs must survive exactly (JSON text, not a float32 attribute).
    expect(parsed).toEqual([
      { name: 'chapter0', placeId: 97235312452456, universeId: 10192566764 },
      { name: 'chapter1', placeId: 87639818897831, universeId: 10192566764 },
    ]);
  });

  it('omits the name key for a single-place (nameless) target', () => {
    const attributes = buildDeployMetadataAttributes({}, PLACE, [
      { placeId: 123, universeId: 456 },
    ]);
    const parsed = JSON.parse(attributes.Places as string);
    expect(parsed).toEqual([{ placeId: 123, universeId: 456 }]);
    expect('name' in parsed[0]).toBe(false);
  });
});

describe('packageUsesManifestAsync', () => {
  it('is true for the manifest package itself', async () => {
    await withPackageJsonAsync(
      { name: '@quenty/nevermoreclimanifest' },
      async (dir) => {
        expect(await packageUsesManifestAsync(dir)).toBe(true);
      }
    );
  });

  it('is true for a direct dependent', async () => {
    await withPackageJsonAsync(
      {
        name: '@quenty/somepackage',
        dependencies: { '@quenty/nevermoreclimanifest': 'workspace:*' },
      },
      async (dir) => {
        expect(await packageUsesManifestAsync(dir)).toBe(true);
      }
    );
  });

  it('is false for an unrelated package', async () => {
    await withPackageJsonAsync(
      {
        name: '@quenty/maid',
        dependencies: { '@quenty/loader': 'workspace:*' },
      },
      async (dir) => {
        expect(await packageUsesManifestAsync(dir)).toBe(false);
      }
    );
  });

  it('is false when there is no package.json', async () => {
    await withPackageJsonAsync(undefined, async (dir) => {
      expect(await packageUsesManifestAsync(dir)).toBe(false);
    });
  });
});
