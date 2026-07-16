import { describe, it, expect } from 'vitest';
import {
  buildDeployMetadataAttributes,
  type GitDeployInfo,
  type DeployPlaceInfo,
} from './deploy-metadata.js';

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
    const attributes = buildDeployMetadataAttributes({}, {
      ...PLACE,
      placeId: 123456789,
      universeId: 987654321,
    });
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
});
