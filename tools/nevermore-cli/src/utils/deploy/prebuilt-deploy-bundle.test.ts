import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { Header } from 'tar';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  type PrebuiltDeployBundle,
  readPrebuiltDeployBundleAsync,
  writePrebuiltDeployBundleAsync,
} from './prebuilt-deploy-bundle.js';

interface RawEntry {
  path: string;
  body?: string;
  type?: 'File' | 'SymbolicLink';
  linkpath?: string;
}

const PROJECT_TEXT = JSON.stringify({ name: 'game', tree: {} });
const SHA = 'a'.repeat(40);

function rawTar(entries: RawEntry[]): Buffer {
  const blocks: Buffer[] = [];
  for (const entry of entries) {
    const body = Buffer.from(entry.body ?? '');
    const header = new Header({
      path: entry.path,
      type: entry.type ?? 'File',
      linkpath: entry.linkpath,
      size: entry.type && entry.type !== 'File' ? 0 : body.length,
      mode: 0o644,
      mtime: new Date(0),
    });
    header.encode();
    blocks.push(header.block!);
    if (!entry.type || entry.type === 'File') {
      const padded = Buffer.alloc(Math.ceil(body.length / 512) * 512);
      body.copy(padded);
      blocks.push(padded);
    }
  }
  blocks.push(Buffer.alloc(1024));
  return Buffer.concat(blocks);
}

function validManifest(): any {
  return {
    formatVersion: 1,
    target: 'integration',
    git: { commit: 'aaaaaaa', version: SHA },
    places: [
      {
        name: '@quenty/integration',
        file: 'place-1.rbxl',
        project: 'project-1.json',
        packageVersion: '1.2.3',
      },
    ],
  };
}

describe('prebuilt deploy bundle', () => {
  let workDir: string;
  const opened: PrebuiltDeployBundle[] = [];

  beforeEach(async () => {
    workDir = await fs.mkdtemp(path.join(os.tmpdir(), 'deploy-bundle-'));
  });

  afterEach(async () => {
    for (const bundle of opened.splice(0)) {
      await bundle.buildContext.cleanupAsync();
    }
    await fs.rm(workDir, { recursive: true, force: true });
  });

  async function readAsync(file: string) {
    const bundle = await readPrebuiltDeployBundleAsync(file);
    opened.push(bundle);
    return bundle;
  }

  async function writeRawAsync(entries: RawEntry[]): Promise<string> {
    const file = path.join(workDir, 'raw.nevermore.deploy.tar');
    await fs.writeFile(file, rawTar(entries));
    return file;
  }

  async function writeManifestAsync(
    manifest: any,
    projectText = PROJECT_TEXT
  ): Promise<string> {
    return writeRawAsync([
      { path: 'manifest.json', body: JSON.stringify(manifest) },
      { path: 'place-1.rbxl', body: 'place bytes' },
      { path: 'project-1.json', body: projectText },
    ]);
  }

  it('round-trips places, projects, versions and git info through one file', async () => {
    const place = path.join(workDir, 'source.rbxl');
    const project = path.join(workDir, 'default.project.json');
    await fs.writeFile(place, 'place bytes');
    await fs.writeFile(project, PROJECT_TEXT);
    const file = path.join(workDir, 'out', 'pr-1.nevermore.deploy.tar');

    await writePrebuiltDeployBundleAsync(
      file,
      'integration',
      { commit: 'abc1234', version: SHA, branch: 'feature/x' },
      [
        {
          name: '@quenty/integration',
          rbxlPath: place,
          projectPath: project,
          packageVersion: '1.0.0',
        },
      ]
    );
    const bundle = await readAsync(file);

    expect(bundle.target).toBe('integration');
    expect(bundle.git).toEqual({
      commit: 'abc1234',
      version: SHA,
      branch: 'feature/x',
    });
    expect(bundle.places).toHaveLength(1);
    expect(bundle.places[0]!.name).toBe('@quenty/integration');
    expect(bundle.places[0]!.packageVersion).toBe('1.0.0');
    expect(await fs.readFile(bundle.places[0]!.rbxlPath, 'utf-8')).toBe(
      'place bytes'
    );
    expect(await fs.readFile(bundle.places[0]!.projectPath, 'utf-8')).toBe(
      PROJECT_TEXT
    );
  });

  it('reads an empty bundle as no places', async () => {
    const file = path.join(workDir, 'empty.nevermore.deploy.tar');
    await writePrebuiltDeployBundleAsync(file, 'integration', {}, []);

    const bundle = await readAsync(file);

    expect(bundle.places).toEqual([]);
  });

  it('never writes outside its own directory for an entry that escapes', async () => {
    const file = await writeRawAsync([
      { path: 'manifest.json', body: JSON.stringify(validManifest()) },
      { path: 'place-1.rbxl', body: 'place bytes' },
      { path: 'project-1.json', body: PROJECT_TEXT },
      { path: '../escaped.json', body: 'evil' },
    ]);

    await expect(readAsync(file)).rejects.toThrow('unexpected entry');
    await expect(
      fs.stat(path.join(os.tmpdir(), 'escaped.json'))
    ).rejects.toThrow();
  });

  it('rejects a symlink entry', async () => {
    const file = await writeRawAsync([
      { path: 'manifest.json', body: JSON.stringify(validManifest()) },
      { path: 'place-1.rbxl', body: 'place bytes' },
      { path: 'project-1.json', type: 'SymbolicLink', linkpath: '/etc/passwd' },
    ]);

    await expect(readAsync(file)).rejects.toThrow('not a regular file');
  });

  it('rejects a file the manifest does not list', async () => {
    const file = await writeRawAsync([
      { path: 'manifest.json', body: JSON.stringify(validManifest()) },
      { path: 'place-1.rbxl', body: 'place bytes' },
      { path: 'project-1.json', body: PROJECT_TEXT },
      { path: 'place-2.rbxl', body: 'extra' },
    ]);

    await expect(readAsync(file)).rejects.toThrow('every file it holds');
  });

  it('rejects a place pointing at a project file as its place', async () => {
    const manifest = validManifest();
    manifest.places[0].file = 'project-1.json';

    await expect(readAsync(await writeManifestAsync(manifest))).rejects.toThrow(
      'invalid file'
    );
  });

  it('rejects a project without a tree', async () => {
    await expect(
      readAsync(await writeManifestAsync(validManifest(), '{"name":"x"}'))
    ).rejects.toThrow('has no "tree"');
  });

  it.each([
    ['target', (m: any) => (m.target = 'integration; rm -rf /')],
    [
      'package name',
      (m: any) => (m.places[0].name = '@quenty/x [a](http://x)'),
    ],
    ['git version', (m: any) => (m.git.version = 'not-a-sha')],
    ['package version', (m: any) => (m.places[0].packageVersion = '1.0 <b>')],
  ])('rejects an invalid %s', async (label, mutate) => {
    const manifest = validManifest();
    mutate(manifest);

    await expect(readAsync(await writeManifestAsync(manifest))).rejects.toThrow(
      'invalid'
    );
  });

  it('drops a branch name it will not stamp instead of failing', async () => {
    const manifest = validManifest();
    manifest.git.branch = 'main\n<img>';

    const bundle = await readAsync(await writeManifestAsync(manifest));

    expect(bundle.git.branch).toBeUndefined();
    expect(bundle.git.version).toBe(SHA);
  });

  it('rejects an unknown format version', async () => {
    const manifest = validManifest();
    manifest.formatVersion = 2;

    await expect(readAsync(await writeManifestAsync(manifest))).rejects.toThrow(
      'Unsupported bundle format'
    );
  });

  it('names the right command for a tests bundle', async () => {
    const file = await writeRawAsync([
      {
        path: 'manifest.json',
        body: JSON.stringify({
          formatVersion: 1,
          kind: 'tests',
          chunks: [
            {
              file: 'place-1.rbxl',
              packages: [{ name: '@quenty/maid', slug: 'maid' }],
            },
          ],
        }),
      },
      { path: 'place-1.rbxl', body: 'place bytes' },
    ]);

    await expect(readAsync(file)).rejects.toThrow(
      'This is a tests bundle, not a deploy bundle. Run it with "nevermore batch test --bundle <file>".'
    );
  });

  it('rejects a bundle of an unknown kind', async () => {
    const manifest = validManifest();
    manifest.kind = 'mystery';

    await expect(readAsync(await writeManifestAsync(manifest))).rejects.toThrow(
      'unknown kind'
    );
  });
});
