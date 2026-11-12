import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { Header } from 'tar';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  type PrebuiltBatchBundle,
  readPrebuiltBatchBundleAsync,
  writePrebuiltBatchBundleAsync,
} from './prebuilt-batch-bundle.js';

interface RawEntry {
  path: string;
  body?: string;
  type?: 'File' | 'SymbolicLink' | 'Directory';
  linkpath?: string;
}

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
    chunks: [
      {
        file: 'place-1.rbxl',
        packages: [
          { name: '@quenty/rx', slug: 'rx', hasJestConfig: true },
          { name: '@quenty/maid', slug: 'maid', hasJestConfig: false },
        ],
      },
    ],
  };
}

describe('prebuilt batch bundle', () => {
  let workDir: string;
  const opened: PrebuiltBatchBundle[] = [];

  beforeEach(async () => {
    workDir = await fs.mkdtemp(path.join(os.tmpdir(), 'prebuilt-bundle-'));
  });

  afterEach(async () => {
    for (const bundle of opened.splice(0)) {
      await bundle.buildContext.cleanupAsync();
    }
    await fs.rm(workDir, { recursive: true, force: true });
  });

  async function readAsync(file: string) {
    const bundle = await readPrebuiltBatchBundleAsync(file);
    opened.push(bundle);
    return bundle;
  }

  async function writeRawAsync(entries: RawEntry[]): Promise<string> {
    const file = path.join(workDir, 'raw.nevermore.tests.tar');
    await fs.writeFile(file, rawTar(entries));
    return file;
  }

  async function writeManifestAsync(manifest: any): Promise<string> {
    return writeRawAsync([
      { path: 'manifest.json', body: JSON.stringify(manifest) },
      { path: 'place-1.rbxl', body: 'place bytes' },
    ]);
  }

  it('round-trips places, slugs and jest.config flags through one file', async () => {
    const source = path.join(workDir, 'source.rbxl');
    await fs.writeFile(source, 'place bytes');
    const file = path.join(workDir, 'out', 'pr-1.nevermore.tests.tar');
    await writePrebuiltBatchBundleAsync(
      file,
      [
        {
          rbxlPath: source,
          slugMap: new Map([
            ['@quenty/rx', 'rx'],
            ['@quenty/maid', 'maid'],
          ]),
          sizeBytes: 11,
        },
      ],
      new Map([['@quenty/rx', true]])
    );

    const bundle = await readAsync(file);

    expect(bundle.packages).toEqual([
      { name: '@quenty/rx', hasJestConfig: true },
      { name: '@quenty/maid', hasJestConfig: false },
    ]);
    expect(bundle.chunks).toHaveLength(1);
    expect(bundle.chunks[0]!.sizeBytes).toBe(11);
    expect([...bundle.chunks[0]!.slugMap]).toEqual([
      ['@quenty/rx', 'rx'],
      ['@quenty/maid', 'maid'],
    ]);
    expect(await fs.readFile(bundle.chunks[0]!.rbxlPath, 'utf-8')).toBe(
      'place bytes'
    );
  });

  it('reads an empty bundle as no packages', async () => {
    const file = path.join(workDir, 'empty.nevermore.tests.tar');
    await writePrebuiltBatchBundleAsync(file, [], new Map());

    const bundle = await readAsync(file);

    expect(bundle.packages).toEqual([]);
    expect(bundle.chunks).toEqual([]);
  });

  it('removes the unpacked places on cleanup', async () => {
    const bundle = await readPrebuiltBatchBundleAsync(
      await writeManifestAsync(validManifest())
    );
    const placePath = bundle.chunks[0]!.rbxlPath;

    await bundle.buildContext.cleanupAsync();

    await expect(fs.stat(placePath)).rejects.toThrow();
  });

  it('never writes outside its own directory for an entry that escapes', async () => {
    const file = await writeRawAsync([
      { path: 'manifest.json', body: JSON.stringify(validManifest()) },
      { path: 'place-1.rbxl', body: 'place bytes' },
      { path: '../escaped.rbxl', body: 'evil' },
    ]);

    await expect(readAsync(file)).rejects.toThrow('unexpected entry');
    await expect(
      fs.stat(path.join(os.tmpdir(), 'escaped.rbxl'))
    ).rejects.toThrow();
  });

  it('rejects a symlink entry', async () => {
    const file = await writeRawAsync([
      { path: 'manifest.json', body: JSON.stringify(validManifest()) },
      { path: 'place-1.rbxl', type: 'SymbolicLink', linkpath: '/etc/passwd' },
    ]);

    await expect(readAsync(file)).rejects.toThrow('not a regular file');
  });

  it('rejects a place the manifest does not list', async () => {
    const file = await writeRawAsync([
      { path: 'manifest.json', body: JSON.stringify(validManifest()) },
      { path: 'place-1.rbxl', body: 'place bytes' },
      { path: 'place-2.rbxl', body: 'extra' },
    ]);

    await expect(readAsync(file)).rejects.toThrow('every place it holds');
  });

  it('rejects a manifest that lists a place the bundle does not hold', async () => {
    const manifest = validManifest();
    manifest.chunks[0].file = 'place-2.rbxl';

    await expect(readAsync(await writeManifestAsync(manifest))).rejects.toThrow(
      'invalid place file'
    );
  });

  it('rejects a file that is not a tar', async () => {
    const file = path.join(workDir, 'junk.nevermore.tests.tar');
    await fs.writeFile(file, 'not a tar at all');

    await expect(readAsync(file)).rejects.toThrow();
  });

  it('rejects a slug that could break out of the batch script', async () => {
    const manifest = validManifest();
    manifest.chunks[0].packages[0].slug = 'rx"]] print("hi") --';

    await expect(readAsync(await writeManifestAsync(manifest))).rejects.toThrow(
      'invalid slug'
    );
  });

  it('accepts a multi-place target name with a free-form place name', async () => {
    const manifest = validManifest();
    manifest.chunks[0].packages[0].name = '@quenty/rx - Hub (Test) + Lobby é';

    const bundle = await readAsync(await writeManifestAsync(manifest));

    expect(bundle.packages[0]!.name).toBe('@quenty/rx - Hub (Test) + Lobby é');
  });

  it.each([
    '@quenty/rx | injected',
    '@quenty/rx<img>',
    '@quenty/rx\nline',
    '@quenty/rx [Approved](https://evil.example)',
    '@quenty/rx ![x](p.png)',
    '@quenty/rx cc @someuser',
    '@quenty/rx https://evil.example',
  ])(
    'rejects a package name that could break the PR comment: %j',
    async (name) => {
      const manifest = validManifest();
      manifest.chunks[0].packages[0].name = name;

      await expect(
        readAsync(await writeManifestAsync(manifest))
      ).rejects.toThrow('invalid package name');
    }
  );

  it('rejects a package listed twice', async () => {
    const manifest = validManifest();
    manifest.chunks[0].packages[1].name = '@quenty/rx';

    await expect(readAsync(await writeManifestAsync(manifest))).rejects.toThrow(
      'more than once'
    );
  });

  it('rejects an unknown format version', async () => {
    const manifest = validManifest();
    manifest.formatVersion = 2;

    await expect(readAsync(await writeManifestAsync(manifest))).rejects.toThrow(
      'Unsupported bundle format'
    );
  });

  it('names the right command for a deploy bundle, before its unexpected entries', async () => {
    const file = await writeRawAsync([
      {
        path: 'manifest.json',
        body: JSON.stringify({
          formatVersion: 1,
          kind: 'deploy',
          target: 'integration',
          places: [],
        }),
      },
      { path: 'place-1.rbxl', body: 'place bytes' },
      { path: 'project-1.json', body: '{}' },
    ]);

    await expect(readAsync(file)).rejects.toThrow(
      'This is a deploy bundle, not a tests bundle. Run it with "nevermore batch deploy --bundle <file>".'
    );
  });
});
