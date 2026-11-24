import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import {
  findPackageContainingAsync,
  findWorkspaceRootAsync,
  isInLernaPackages,
  listPublishablePackagesAsync,
  listWorkspacePackagesAsync,
} from './workspace-utils.js';

describe('workspace-utils', () => {
  let root: string;

  beforeEach(async () => {
    root = await fs.realpath(
      await fs.mkdtemp(path.join(os.tmpdir(), 'nevermore-ws-'))
    );
  });

  afterEach(async () => {
    await fs.rm(root, { recursive: true, force: true });
  });

  async function writeJsonAsync(relativePath: string, value: unknown) {
    const filePath = path.join(root, relativePath);
    await fs.mkdir(path.dirname(filePath), { recursive: true });
    await fs.writeFile(filePath, JSON.stringify(value));
  }

  describe('findWorkspaceRootAsync', () => {
    it('finds the package.json with workspaces from a nested package', async () => {
      await writeJsonAsync('package.json', {
        name: 'root',
        workspaces: ['packages/*'],
      });
      await writeJsonAsync('packages/a/package.json', { name: 'a' });

      expect(
        await findWorkspaceRootAsync(path.join(root, 'packages', 'a'))
      ).toBe(root);
    });

    it('finds a lerna.json root', async () => {
      await writeJsonAsync('lerna.json', { packages: ['src/*'] });
      await writeJsonAsync('src/a/package.json', { name: 'a' });

      expect(await findWorkspaceRootAsync(path.join(root, 'src', 'a'))).toBe(
        root
      );
    });

    it('treats a lone package as its own root', async () => {
      await writeJsonAsync('lib/package.json', { name: 'lib' });

      expect(await findWorkspaceRootAsync(path.join(root, 'lib'))).toBe(
        path.join(root, 'lib')
      );
    });
  });

  describe('listWorkspacePackagesAsync', () => {
    it('returns the single package when there is no workspace', async () => {
      await writeJsonAsync('package.json', { name: 'solo', version: '1.0.0' });
      await fs.writeFile(path.join(root, 'package-lock.json'), '{}');

      expect(await listWorkspacePackagesAsync(root)).toEqual([
        { name: 'solo', path: root },
      ]);
    });
  });

  describe('listPublishablePackagesAsync', () => {
    it('skips private packages', async () => {
      await writeJsonAsync('package.json', {
        name: 'solo',
        version: '2.0.0',
        private: true,
      });
      await fs.writeFile(path.join(root, 'package-lock.json'), '{}');

      expect(await listPublishablePackagesAsync(root)).toEqual([]);
    });

    it('reads repository and registry for a public package', async () => {
      await writeJsonAsync('package.json', {
        name: 'solo',
        version: '2.0.0',
        repository: 'owner/repo',
        publishConfig: { registry: 'https://example.com/' },
      });
      await fs.writeFile(path.join(root, 'package-lock.json'), '{}');

      expect(await listPublishablePackagesAsync(root)).toEqual([
        {
          name: 'solo',
          version: '2.0.0',
          path: root,
          repository: 'owner/repo',
          registry: 'https://example.com/',
        },
      ]);
    });
  });

  describe('findPackageContainingAsync', () => {
    it('finds the package the directory is in, ignoring the root', async () => {
      await fs.mkdir(path.join(root, 'src', 'maid', 'src'), {
        recursive: true,
      });
      const packages = [
        { name: 'root', path: root },
        { name: 'maid', path: path.join(root, 'src', 'maid') },
      ];

      expect(
        (
          await findPackageContainingAsync(
            packages,
            path.join(root, 'src', 'maid', 'src'),
            root
          )
        )?.name
      ).toBe('maid');
      expect(await findPackageContainingAsync(packages, root, root)).toBe(
        undefined
      );
    });
  });

  describe('isInLernaPackages', () => {
    const globs = ['src/*', 'tools/*'];

    it('matches direct children of the globbed directories', () => {
      expect(isInLernaPackages('src/maid', globs)).toBe(true);
      expect(isInLernaPackages('tools/nevermore-cli', globs)).toBe(true);
    });

    it('skips other workspace folders and the root', () => {
      expect(isInLernaPackages('plugins/preview-plugin', globs)).toBe(false);
      expect(isInLernaPackages('', globs)).toBe(false);
      expect(isInLernaPackages('src/a/b', globs)).toBe(false);
    });

    it('throws on globs it does not understand', () => {
      expect(() => isInLernaPackages('src/maid', ['src/**'])).toThrow();
    });
  });
});
