import { describe, it, expect } from 'vitest';
import * as path from 'path';
import {
  getPluginPackageDir,
  resolvePluginPackageDir,
} from './plugin-package-dir.js';

const packageRoot = path.join('repo', 'tools', 'studio-bridge');
const monorepoDir = path.join(
  packageRoot,
  '..',
  '..',
  'plugins',
  'studio-bridge-plugin'
);
const bundledDir = path.join(packageRoot, 'studio-bridge-plugin');

describe('resolvePluginPackageDir', () => {
  it("prefers the monorepo's plugin, so a checkout builds live source", () => {
    expect(resolvePluginPackageDir(packageRoot, () => true)).toBe(monorepoDir);
  });

  it('falls back to the copy packed into a published package', () => {
    expect(
      resolvePluginPackageDir(packageRoot, (dir) => dir === bundledDir)
    ).toBe(bundledDir);
  });

  it('says where it looked when neither is there', () => {
    expect(() => resolvePluginPackageDir(packageRoot, () => false)).toThrow(
      'This studio-bridge install is missing its Studio plugin.'
    );
  });

  it('finds the plugin in this checkout', () => {
    expect(path.basename(getPluginPackageDir())).toBe('studio-bridge-plugin');
    expect(getPluginPackageDir()).toContain('plugins');
  });
});
