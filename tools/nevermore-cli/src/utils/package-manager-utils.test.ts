import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import {
  buildAddPackagesCommand,
  detectPackageManagerAsync,
  isPackageManager,
} from './package-manager-utils.js';

describe('package-manager-utils', () => {
  let root: string;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'nevermore-pm-'));
  });

  afterEach(async () => {
    await fs.rm(root, { recursive: true, force: true });
  });

  async function writeFileAsync(relativePath: string, contents: string) {
    const filePath = path.join(root, relativePath);
    await fs.mkdir(path.dirname(filePath), { recursive: true });
    await fs.writeFile(filePath, contents);
  }

  describe('detectPackageManagerAsync', () => {
    it('reads the packageManager field', async () => {
      await writeFileAsync(
        'package.json',
        JSON.stringify({ packageManager: 'pnpm@10.27.0' })
      );

      expect(await detectPackageManagerAsync(root)).toBe('pnpm');
    });

    it('prefers the packageManager field over a lockfile', async () => {
      await writeFileAsync(
        'package.json',
        JSON.stringify({ packageManager: 'yarn@4.0.0' })
      );
      await writeFileAsync('package-lock.json', '{}');

      expect(await detectPackageManagerAsync(root)).toBe('yarn');
    });

    it('falls back to lockfiles', async () => {
      await writeFileAsync('package.json', JSON.stringify({ name: 'game' }));
      await writeFileAsync('pnpm-lock.yaml', '');

      expect(await detectPackageManagerAsync(root)).toBe('pnpm');
    });

    it('treats a pnpm workspace file as pnpm', async () => {
      await writeFileAsync('pnpm-workspace.yaml', 'packages:\n');

      expect(await detectPackageManagerAsync(root)).toBe('pnpm');
    });

    it('walks up from a subdirectory', async () => {
      await writeFileAsync(
        'package.json',
        JSON.stringify({ packageManager: 'pnpm@10.27.0' })
      );
      await fs.mkdir(path.join(root, 'src', 'shared'), { recursive: true });

      expect(
        await detectPackageManagerAsync(path.join(root, 'src', 'shared'))
      ).toBe('pnpm');
    });

    it('lets the nearest project win', async () => {
      await writeFileAsync(
        'package.json',
        JSON.stringify({ packageManager: 'pnpm@10.27.0' })
      );
      await writeFileAsync(
        'nested/package.json',
        JSON.stringify({ packageManager: 'yarn@4.0.0' })
      );

      expect(await detectPackageManagerAsync(path.join(root, 'nested'))).toBe(
        'yarn'
      );
    });

    it('ignores an unknown packageManager field', async () => {
      await writeFileAsync(
        'package.json',
        JSON.stringify({ packageManager: 'cnpm@1.0.0' })
      );
      await writeFileAsync('yarn.lock', '');

      expect(await detectPackageManagerAsync(root)).toBe('yarn');
    });

    it('survives malformed package.json', async () => {
      await writeFileAsync('package.json', '{ not json');
      await writeFileAsync('pnpm-lock.yaml', '');

      expect(await detectPackageManagerAsync(root)).toBe('pnpm');
    });

    it('defaults to pnpm', async () => {
      expect(await detectPackageManagerAsync(root)).toBe('pnpm');
    });

    it('still honors an npm project', async () => {
      await writeFileAsync('package.json', JSON.stringify({ name: 'game' }));
      await writeFileAsync('package-lock.json', '{}');

      expect(await detectPackageManagerAsync(root)).toBe('npm');
    });
  });

  describe('buildAddPackagesCommand', () => {
    it('uses install for npm', () => {
      expect(buildAddPackagesCommand('npm', ['@quenty/blend'])).toEqual({
        command: 'npm',
        args: ['install', '@quenty/blend'],
      });
    });

    it('uses add for everything else', () => {
      expect(buildAddPackagesCommand('pnpm', ['@quenty/blend'])).toEqual({
        command: 'pnpm',
        args: ['add', '@quenty/blend'],
      });
      expect(buildAddPackagesCommand('yarn', ['@quenty/maid'])).toEqual({
        command: 'yarn',
        args: ['add', '@quenty/maid'],
      });
      expect(buildAddPackagesCommand('bun', ['@quenty/maid'])).toEqual({
        command: 'bun',
        args: ['add', '@quenty/maid'],
      });
    });
  });

  describe('isPackageManager', () => {
    it('accepts known managers and rejects others', () => {
      expect(isPackageManager('pnpm')).toBe(true);
      expect(isPackageManager('deno')).toBe(false);
    });
  });
});
