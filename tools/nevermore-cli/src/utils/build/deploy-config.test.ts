import { describe, it, expect } from 'vitest';
import {
  type DeployConfig,
  type DeployTarget,
  resolveDefaultTargetName,
} from './deploy-config.js';

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
