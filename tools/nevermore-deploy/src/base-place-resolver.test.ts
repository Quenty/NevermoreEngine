import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { BasePlaceResolver } from './base-place-resolver.js';
import {
  loadDeployLockAsync,
  resolveDeployLockPath,
  saveDeployLockAsync,
  createEmptyDeployLock,
  type DeployLock,
} from './deploy-lock.js';
import { type BasePlaceConfig } from './deploy-config.js';

let packageDir: string;

beforeEach(async () => {
  packageDir = await fs.mkdtemp(path.join(os.tmpdir(), 'base-place-resolver-'));
});

afterEach(async () => {
  await fs.rm(packageDir, { recursive: true, force: true });
});

function makeSource(versions: Record<number, number> = { 33: 158 }) {
  return {
    resolveLatestPlaceVersionAsync: vi.fn(
      async (_universeId: number, placeId: number) => versions[placeId]!
    ),
  };
}

function makeBasePlace(over: Partial<BasePlaceConfig> = {}): BasePlaceConfig {
  return { universeId: 1, placeId: 33, ...over };
}

function makeCountingSource(version = 158) {
  let calls = 0;
  return {
    calls: () => calls,
    resolveLatestPlaceVersionAsync: async () => {
      calls++;
      // Yield so a second caller lands while this one is still in flight.
      await new Promise((resolve) => setTimeout(resolve, 5));
      return version;
    },
  };
}

async function writeLockAsync(lock: DeployLock): Promise<void> {
  await saveDeployLockAsync(resolveDeployLockPath(packageDir), lock);
}

async function readLockAsync() {
  return loadDeployLockAsync(resolveDeployLockPath(packageDir));
}

describe('BasePlaceResolver', () => {
  it('returns a numeric pin without touching the lock or the network', async () => {
    const source = makeSource();
    const resolver = new BasePlaceResolver({ source });

    const version = await resolver.resolveAsync(
      packageDir,
      makeBasePlace({ version: 42 })
    );

    expect(version).toBe(42);
    expect(source.resolveLatestPlaceVersionAsync).not.toHaveBeenCalled();
    expect(await resolver.flushAsync()).toEqual([]);
    expect(await readLockAsync()).toBeUndefined();
  });

  it('resolves and records a keyword pin when the lock has no entry', async () => {
    const source = makeSource();
    const resolver = new BasePlaceResolver({ source });

    const version = await resolver.resolveAsync(
      packageDir,
      makeBasePlace({ version: 'published' })
    );
    expect(version).toBe(158);

    expect(await resolver.flushAsync()).toEqual([
      resolveDeployLockPath(packageDir),
    ]);
    expect((await readLockAsync())?.basePlaces['33']).toEqual({
      version: 158,
      from: 'published',
    });
  });

  it('treats an omitted version as a published pin', async () => {
    const source = makeSource();
    const resolver = new BasePlaceResolver({ source });

    await resolver.resolveAsync(packageDir, makeBasePlace());

    expect(source.resolveLatestPlaceVersionAsync).toHaveBeenCalledWith(
      1,
      33,
      'published'
    );
    await resolver.flushAsync();
    expect((await readLockAsync())?.basePlaces['33']?.from).toBe('published');
  });

  it('uses the locked version without hitting the network', async () => {
    await writeLockAsync({
      lockfileVersion: 1,
      basePlaces: { '33': { version: 100, from: 'published' } },
    });
    const source = makeSource();
    const resolver = new BasePlaceResolver({ source });

    const version = await resolver.resolveAsync(
      packageDir,
      makeBasePlace({ version: 'published' })
    );

    expect(version).toBe(100);
    expect(source.resolveLatestPlaceVersionAsync).not.toHaveBeenCalled();
    expect(await resolver.flushAsync()).toEqual([]);
  });

  it('re-resolves when the config switches which version type it tracks', async () => {
    await writeLockAsync({
      lockfileVersion: 1,
      basePlaces: { '33': { version: 100, from: 'published' } },
    });
    const source = makeSource();
    const resolver = new BasePlaceResolver({ source });

    const version = await resolver.resolveAsync(
      packageDir,
      makeBasePlace({ version: 'saved' })
    );

    expect(version).toBe(158);
    expect(source.resolveLatestPlaceVersionAsync).toHaveBeenCalledWith(
      1,
      33,
      'saved'
    );
    await resolver.flushAsync();
    expect((await readLockAsync())?.basePlaces['33']).toEqual({
      version: 158,
      from: 'saved',
    });
  });

  it('resolves a shared base place once across packages but records it in each', async () => {
    const otherDir = await fs.mkdtemp(path.join(os.tmpdir(), 'other-pkg-'));
    try {
      const source = makeSource();
      const resolver = new BasePlaceResolver({ source });

      const [a, b] = await Promise.all([
        resolver.resolveAsync(packageDir, makeBasePlace({ version: 'saved' })),
        resolver.resolveAsync(otherDir, makeBasePlace({ version: 'saved' })),
      ]);

      expect([a, b]).toEqual([158, 158]);
      expect(source.resolveLatestPlaceVersionAsync).toHaveBeenCalledTimes(1);
      expect((await resolver.flushAsync()).sort()).toEqual(
        [
          resolveDeployLockPath(packageDir),
          resolveDeployLockPath(otherDir),
        ].sort()
      );
    } finally {
      await fs.rm(otherDir, { recursive: true, force: true });
    }
  });

  it('records every place when one package resolves them concurrently', async () => {
    // A multi-place target fans out ~10 wide against a single package
    // directory, so all of these share one lock file.
    const source = makeSource({ 11: 110, 22: 220, 33: 330 });
    const resolver = new BasePlaceResolver({ source });

    await Promise.all(
      [11, 22, 33].map((placeId) =>
        resolver.resolveAsync(
          packageDir,
          makeBasePlace({ placeId, version: 'published' })
        )
      )
    );
    await resolver.flushAsync();

    expect((await readLockAsync())?.basePlaces).toEqual({
      '11': { version: 110, from: 'published' },
      '22': { version: 220, from: 'published' },
      '33': { version: 330, from: 'published' },
    });
  });

  it('asks the source separately for the saved and published versions', async () => {
    const source = {
      resolveLatestPlaceVersionAsync: vi.fn(
        async (_universeId: number, _placeId: number, versionType: string) =>
          versionType === 'saved' ? 999 : 100
      ),
    };
    const resolver = new BasePlaceResolver({ source });
    const otherDir = await fs.mkdtemp(path.join(os.tmpdir(), 'other-pkg-'));

    try {
      // Same place id, different keyword: the dedupe cache must not serve one
      // question's answer to the other.
      expect(
        await resolver.resolveAsync(
          packageDir,
          makeBasePlace({ version: 'published' })
        )
      ).toBe(100);
      expect(
        await resolver.resolveAsync(
          otherDir,
          makeBasePlace({ version: 'saved' })
        )
      ).toBe(999);
      expect(source.resolveLatestPlaceVersionAsync).toHaveBeenCalledTimes(2);
    } finally {
      await fs.rm(otherDir, { recursive: true, force: true });
    }
  });

  it('refuses a base place tracked as two version types in one lock', async () => {
    const resolver = new BasePlaceResolver({ source: makeSource() });

    await resolver.resolveAsync(
      packageDir,
      makeBasePlace({ version: 'published' })
    );

    await expect(
      resolver.resolveAsync(packageDir, makeBasePlace({ version: 'saved' }))
    ).rejects.toThrowError(/tracked as both "published" and "saved"/);
  });

  it('leaves untouched entries in place rather than pruning them', async () => {
    await writeLockAsync({
      lockfileVersion: 1,
      basePlaces: {
        '33': { version: 100, from: 'published' },
        '99': { version: 7, from: 'saved' },
      },
    });
    const resolver = new BasePlaceResolver({ source: makeSource() });

    await resolver.resolveAsync(
      packageDir,
      makeBasePlace({ version: 'saved' })
    );
    await resolver.flushAsync();

    expect((await readLockAsync())?.basePlaces['99']).toEqual({
      version: 7,
      from: 'saved',
    });
  });

  it('does not write when nothing changed', async () => {
    await writeLockAsync({
      lockfileVersion: 1,
      basePlaces: { '33': { version: 158, from: 'published' } },
    });
    const resolver = new BasePlaceResolver({ source: makeSource() });

    await resolver.resolveAsync(
      packageDir,
      makeBasePlace({ version: 'published' })
    );

    expect(await resolver.flushAsync()).toEqual([]);
  });

  describe('frozen', () => {
    it('serves a matching entry', async () => {
      await writeLockAsync({
        lockfileVersion: 1,
        basePlaces: { '33': { version: 100, from: 'published' } },
      });
      const source = makeSource();
      const resolver = new BasePlaceResolver({ source, frozen: true });

      expect(
        await resolver.resolveAsync(
          packageDir,
          makeBasePlace({ version: 'published' })
        )
      ).toBe(100);
      expect(source.resolveLatestPlaceVersionAsync).not.toHaveBeenCalled();
    });

    it('refuses to resolve a missing entry', async () => {
      const resolver = new BasePlaceResolver({
        source: makeSource(),
        frozen: true,
      });

      await expect(
        resolver.resolveAsync(packageDir, makeBasePlace({ version: 'saved' }))
      ).rejects.toThrowError(/no entry in .*deploy\.nevermore\.lock\.json/);
    });

    it('refuses when the config asks for a different version type', async () => {
      await writeLockAsync({
        lockfileVersion: 1,
        basePlaces: { '33': { version: 100, from: 'published' } },
      });
      const resolver = new BasePlaceResolver({
        source: makeSource(),
        frozen: true,
      });

      await expect(
        resolver.resolveAsync(packageDir, makeBasePlace({ version: 'saved' }))
      ).rejects.toThrowError(/now asks for saved/);
    });

    it('still serves numeric pins', async () => {
      const resolver = new BasePlaceResolver({
        source: makeSource(),
        frozen: true,
      });

      expect(
        await resolver.resolveAsync(packageDir, makeBasePlace({ version: 9 }))
      ).toBe(9);
    });
  });

  describe('refresh', () => {
    it('re-resolves past a matching lock entry and records the new version', async () => {
      await writeLockAsync({
        lockfileVersion: 1,
        basePlaces: { '33': { version: 100, from: 'published' } },
      });
      const source = makeSource();
      const resolver = new BasePlaceResolver({ source, refresh: true });

      expect(
        await resolver.resolveAsync(
          packageDir,
          makeBasePlace({ version: 'published' })
        )
      ).toBe(158);
      expect(source.resolveLatestPlaceVersionAsync).toHaveBeenCalled();

      expect(await resolver.flushAsync()).toEqual([
        resolveDeployLockPath(packageDir),
      ]);
      expect((await readLockAsync())?.basePlaces['33']).toEqual({
        version: 158,
        from: 'published',
      });
    });

    it('leaves a numeric pin alone', async () => {
      const source = makeSource();
      const resolver = new BasePlaceResolver({ source, refresh: true });

      expect(
        await resolver.resolveAsync(packageDir, makeBasePlace({ version: 42 }))
      ).toBe(42);
      expect(source.resolveLatestPlaceVersionAsync).not.toHaveBeenCalled();
    });

    it('does not dirty the lock when the version has not moved', async () => {
      await writeLockAsync({
        lockfileVersion: 1,
        basePlaces: { '33': { version: 158, from: 'published' } },
      });
      const resolver = new BasePlaceResolver({
        source: makeSource(),
        refresh: true,
      });

      await resolver.resolveAsync(
        packageDir,
        makeBasePlace({ version: 'published' })
      );

      expect(await resolver.flushAsync()).toEqual([]);
    });

    it('cannot be combined with frozen', () => {
      expect(
        () =>
          new BasePlaceResolver({
            source: makeSource(),
            frozen: true,
            refresh: true,
          })
      ).toThrowError(/cannot be both frozen and refreshing/);
    });
  });

  describe('peekAsync', () => {
    it('reads a locked version without recording anything', async () => {
      await writeLockAsync({
        lockfileVersion: 1,
        basePlaces: { '33': { version: 100, from: 'published' } },
      });
      const source = makeSource();
      const resolver = new BasePlaceResolver({ source });

      expect(
        await resolver.peekAsync(
          packageDir,
          makeBasePlace({ version: 'published' })
        )
      ).toBe(100);
      expect(source.resolveLatestPlaceVersionAsync).not.toHaveBeenCalled();
      expect(await resolver.flushAsync()).toEqual([]);
    });

    it('returns undefined when the lock tracks a different version type', async () => {
      await writeLockAsync({
        lockfileVersion: 1,
        basePlaces: { '33': { version: 100, from: 'published' } },
      });
      const resolver = new BasePlaceResolver({ source: makeSource() });

      expect(
        await resolver.peekAsync(
          packageDir,
          makeBasePlace({ version: 'saved' })
        )
      ).toBeUndefined();
    });

    it('returns undefined when the lock has no entry', async () => {
      const resolver = new BasePlaceResolver({ source: makeSource() });

      expect(
        await resolver.peekAsync(
          packageDir,
          makeBasePlace({ version: 'published' })
        )
      ).toBeUndefined();
    });

    it('returns a numeric pin as-is', async () => {
      const resolver = new BasePlaceResolver({ source: makeSource() });

      expect(
        await resolver.peekAsync(packageDir, makeBasePlace({ version: 7 }))
      ).toBe(7);
    });
  });

  it('lets a later attempt retry after a failed lookup', async () => {
    const source = {
      resolveLatestPlaceVersionAsync: vi
        .fn()
        .mockRejectedValueOnce(new Error('network went away'))
        .mockResolvedValueOnce(158),
    };
    const resolver = new BasePlaceResolver({ source });

    await expect(
      resolver.resolveAsync(packageDir, makeBasePlace({ version: 'saved' }))
    ).rejects.toThrowError(/network went away/);

    expect(
      await resolver.resolveAsync(
        packageDir,
        makeBasePlace({ version: 'saved' })
      )
    ).toBe(158);
  });

  it('loads the lock once when callers race for the same package', async () => {
    const source = makeCountingSource();
    const resolver = new BasePlaceResolver({ source });

    await Promise.all([
      resolver.resolveAsync(packageDir, makeBasePlace({ version: 'saved' })),
      resolver.resolveAsync(packageDir, makeBasePlace({ version: 'saved' })),
    ]);

    expect(source.calls()).toBe(1);
    await resolver.flushAsync();
    expect((await readLockAsync())?.basePlaces['33']?.version).toBe(158);
  });

  it('surfaces a corrupt lock rather than regenerating it', async () => {
    await fs.writeFile(resolveDeployLockPath(packageDir), '{ not json');
    const resolver = new BasePlaceResolver({ source: makeSource() });

    await expect(
      resolver.resolveAsync(packageDir, makeBasePlace({ version: 'saved' }))
    ).rejects.toThrowError(/not valid JSON/);
  });
});

describe('deploy lock file', () => {
  it('round-trips and sorts entries for reviewable diffs', async () => {
    const lockPath = resolveDeployLockPath(packageDir);
    const lock = createEmptyDeployLock();
    lock.basePlaces['99'] = { version: 7, from: 'saved' };
    lock.basePlaces['33'] = { version: 158, from: 'published' };
    await saveDeployLockAsync(lockPath, lock);

    const raw = await fs.readFile(lockPath, 'utf-8');
    expect(raw.indexOf('"33"')).toBeLessThan(raw.indexOf('"99"'));
    expect(raw.endsWith('\n')).toBe(true);
    expect(await loadDeployLockAsync(lockPath)).toEqual(lock);
  });

  it('returns undefined when there is no lock file', async () => {
    expect(await loadDeployLockAsync(resolveDeployLockPath(packageDir))).toBe(
      undefined
    );
  });

  it('rejects a future lockfileVersion instead of guessing', async () => {
    const lockPath = resolveDeployLockPath(packageDir);
    await fs.writeFile(
      lockPath,
      JSON.stringify({ lockfileVersion: 2, basePlaces: {} })
    );

    await expect(loadDeployLockAsync(lockPath)).rejects.toThrowError(
      /understands 1/
    );
  });

  it('rejects an entry with an unusable version', async () => {
    const lockPath = resolveDeployLockPath(packageDir);
    await fs.writeFile(
      lockPath,
      JSON.stringify({
        lockfileVersion: 1,
        basePlaces: { '33': { version: 0, from: 'saved' } },
      })
    );

    await expect(loadDeployLockAsync(lockPath)).rejects.toThrowError(
      /invalid "version"/
    );
  });

  it('rejects an entry with an unknown "from"', async () => {
    const lockPath = resolveDeployLockPath(packageDir);
    await fs.writeFile(
      lockPath,
      JSON.stringify({
        lockfileVersion: 1,
        basePlaces: { '33': { version: 5, from: 'latest' } },
      })
    );

    await expect(loadDeployLockAsync(lockPath)).rejects.toThrowError(
      /invalid "from"/
    );
  });
});
