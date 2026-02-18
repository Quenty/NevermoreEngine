import { describe, it, expect } from 'vitest';
import { SourcemapResolver } from './sourcemap-resolver.js';
import type { SourcemapNode } from './sourcemap-types.js';

/**
 * Minimal sourcemap tree that mirrors a typical Nevermore project:
 *
 *   Nevermore (root)
 *     └─ observablecollection
 *          └─ Shared
 *               └─ ObservableList
 *                    └─ ObservableList.spec
 */
function _createTestSourcemap(repoRoot: string): SourcemapNode {
  return {
    name: 'Nevermore',
    className: 'DataModel',
    children: [
      {
        name: 'observablecollection',
        className: 'Folder',
        filePaths: [`${repoRoot}/src/observablecollection/default.project.json`],
        children: [
          {
            name: 'Shared',
            className: 'Folder',
            children: [
              {
                name: 'ObservableList',
                className: 'ModuleScript',
                filePaths: [
                  `${repoRoot}/src/observablecollection/src/Shared/ObservableList.lua`,
                ],
                children: [
                  {
                    name: 'ObservableList.spec',
                    className: 'ModuleScript',
                    filePaths: [
                      `${repoRoot}/src/observablecollection/src/Shared/ObservableList.spec.lua`,
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
      {
        name: 'maid',
        className: 'Folder',
        filePaths: [`${repoRoot}/src/maid/default.project.json`],
        children: [
          {
            name: 'Shared',
            className: 'Folder',
            children: [
              {
                name: 'Maid',
                className: 'ModuleScript',
                filePaths: [`${repoRoot}/src/maid/src/Shared/Maid.lua`],
                children: [
                  {
                    name: 'Maid.spec',
                    className: 'ModuleScript',
                    filePaths: [
                      `${repoRoot}/src/maid/src/Shared/Maid.spec.lua`,
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
  };
}

describe('SourcemapResolver', () => {
  const repoRoot = '/repo';
  const resolver = SourcemapResolver.fromSourcemap(
    _createTestSourcemap(repoRoot),
    repoRoot
  );

  it('resolves a spec file instance path', () => {
    expect(
      resolver.resolve(
        'ServerScriptService.observablecollection.Shared.ObservableList.ObservableList.spec'
      )
    ).toBe('src/observablecollection/src/Shared/ObservableList.spec.lua');
  });

  it('resolves a module instance path', () => {
    expect(
      resolver.resolve(
        'ServerScriptService.observablecollection.Shared.ObservableList'
      )
    ).toBe('src/observablecollection/src/Shared/ObservableList.lua');
  });

  it('strips :LINE suffix before lookup', () => {
    expect(
      resolver.resolve(
        'ServerScriptService.maid.Shared.Maid.Maid.spec:23'
      )
    ).toBe('src/maid/src/Shared/Maid.spec.lua');
  });

  it('returns undefined for unknown paths', () => {
    expect(
      resolver.resolve('ServerScriptService.nonexistent.Shared.Foo')
    ).toBeUndefined();
  });

  it('skips nodes that only have .project.json (no lua files)', () => {
    // The "observablecollection" folder node only has a .project.json filePath.
    // It should not be indexed.
    expect(
      resolver.resolve('ServerScriptService.observablecollection')
    ).toBeUndefined();
  });

  it('resolves paths in a different package', () => {
    expect(
      resolver.resolve('ServerScriptService.maid.Shared.Maid')
    ).toBe('src/maid/src/Shared/Maid.lua');
  });

  it('supports a custom root alias', () => {
    const customResolver = SourcemapResolver.fromSourcemap(
      _createTestSourcemap(repoRoot),
      repoRoot,
      'ReplicatedStorage'
    );

    expect(
      customResolver.resolve(
        'ReplicatedStorage.maid.Shared.Maid'
      )
    ).toBe('src/maid/src/Shared/Maid.lua');

    // ServerScriptService should NOT work with a different alias
    expect(
      customResolver.resolve(
        'ServerScriptService.maid.Shared.Maid'
      )
    ).toBeUndefined();
  });
});
