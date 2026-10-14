import { describe, expect, it } from 'vitest';
import {
  discoverAllTargetPackagesAsync,
  discoverAllTestableBatchTargetsAsync,
} from './changed-packages-utils.js';

// Keep a smoke test against the real workspace: its root config seeds a universe
// for CI without declaring targets. Synthetic deploy-only fixtures miss that.
describe('repository batch discovery', () => {
  it('skips the metadata-only root and still finds the repository test packages', async () => {
    const packages = await discoverAllTargetPackagesAsync('test');
    const names = packages.map((pkg) => pkg.name);
    expect(names).not.toContain('@quenty/nevermore');
    expect(names).toContain('@quenty/nevermoreclimanifest');
    expect(names).toContain('@quenty/nevermore-test-runner');

    const testable = await discoverAllTestableBatchTargetsAsync();
    expect(testable.map((target) => target.packageName)).toEqual(
      expect.arrayContaining([
        '@quenty/nevermoreclimanifest',
        '@quenty/nevermore-test-runner',
      ])
    );
  }, 15_000);
});
