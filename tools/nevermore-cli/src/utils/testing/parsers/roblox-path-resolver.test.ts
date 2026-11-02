import { describe, it, expect } from 'vitest';
import { fileURLToPath } from 'url';
import {
  resolveRobloxTestPath,
  tryResolveRobloxSourceFile,
} from './roblox-path-resolver.js';
import { SourcemapResolver } from '../../sourcemap/index.js';
import type { SourcemapNode } from '../../sourcemap/index.js';

describe('resolveRobloxTestPath', () => {
  it('resolves a standard ServerScriptService path', () => {
    expect(
      resolveRobloxTestPath(
        'ServerScriptService.observablecollection.Shared.ObservableList.spec'
      )
    ).toBe('src/observablecollection/src/Shared/ObservableList.spec.lua');
  });

  it('resolves a nested subdirectory path', () => {
    expect(
      resolveRobloxTestPath('ServerScriptService.maid.Shared.Maid.spec')
    ).toBe('src/maid/src/Shared/Maid.spec.lua');
  });

  it('resolves a deeply nested path', () => {
    expect(
      resolveRobloxTestPath(
        'ServerScriptService.blend.Client.Blend.Spring.SpringObject.spec'
      )
    ).toBe('src/blend/src/Client/Blend/Spring/SpringObject.spec.lua');
  });

  it('handles missing ServerScriptService prefix as fallback', () => {
    expect(
      resolveRobloxTestPath('observablecollection.Shared.ObservableList.spec')
    ).toBe('src/observablecollection/src/Shared/ObservableList.spec.lua');
  });

  it('strips :LINE suffix', () => {
    expect(
      resolveRobloxTestPath(
        'ServerScriptService.observablecollection.Shared.ObservableList.spec:45'
      )
    ).toBe('src/observablecollection/src/Shared/ObservableList.spec.lua');
  });

  it('handles path without ServerScriptService prefix and with :LINE suffix', () => {
    expect(resolveRobloxTestPath('maid.Shared.Maid.spec:23')).toBe(
      'src/maid/src/Shared/Maid.spec.lua'
    );
  });

  it('handles a bare package slug', () => {
    expect(resolveRobloxTestPath('ServerScriptService.maid')).toBe(
      'src/maid/src'
    );
  });

  it('handles a single-level spec path', () => {
    expect(resolveRobloxTestPath('ServerScriptService.maid.Maid.spec')).toBe(
      'src/maid/src/Maid.spec.lua'
    );
  });

  describe('with sourcemap resolver', () => {
    const repoRoot = '/repo';

    const sourcemap: SourcemapNode = {
      name: 'Nevermore',
      className: 'DataModel',
      children: [
        {
          name: 'mypkg',
          className: 'Folder',
          filePaths: [`${repoRoot}/src/mypkg/default.project.json`],
          children: [
            {
              name: 'Shared',
              className: 'Folder',
              children: [
                {
                  name: 'MyModule',
                  className: 'ModuleScript',
                  filePaths: [`${repoRoot}/src/mypkg/src/Shared/MyModule.lua`],
                  children: [
                    {
                      name: 'MyModule.spec',
                      className: 'ModuleScript',
                      filePaths: [
                        `${repoRoot}/src/mypkg/src/Shared/MyModule.spec.lua`,
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

    const resolver = SourcemapResolver.fromSourcemap(sourcemap, repoRoot);

    it('uses sourcemap when path is found', () => {
      expect(
        resolveRobloxTestPath(
          'ServerScriptService.mypkg.Shared.MyModule.MyModule.spec',
          resolver
        )
      ).toBe('src/mypkg/src/Shared/MyModule.spec.lua');
    });

    it('falls back to heuristic when sourcemap has no mapping', () => {
      expect(
        resolveRobloxTestPath(
          'ServerScriptService.unknownpkg.Shared.Foo.spec',
          resolver
        )
      ).toBe('src/unknownpkg/src/Shared/Foo.spec.lua');
    });

    it('strips :LINE suffix with sourcemap', () => {
      expect(
        resolveRobloxTestPath(
          'ServerScriptService.mypkg.Shared.MyModule.MyModule.spec:42',
          resolver
        )
      ).toBe('src/mypkg/src/Shared/MyModule.spec.lua');
    });
  });

  it('unwraps a chunk-name wrapper', () => {
    expect(
      resolveRobloxTestPath(
        '[string "ServerScriptService.saveslot.Server.HasSaveSlotsDataStore"]'
      )
    ).toBe('src/saveslot/src/Server/HasSaveSlotsDataStore.lua');
  });

  it('maps a nested dependency copy to its own package', () => {
    expect(
      resolveRobloxTestPath(
        'ServerScriptService.saveslot.node_modules.@quenty.adorneedata.node_modules.@quenty.attributeutils.node_modules.@quenty.baseobject.node_modules.@quenty.maid.Shared.Maid'
      )
    ).toBe('src/maid/src/Shared/Maid.lua');
  });
});

describe('tryResolveRobloxSourceFile', () => {
  const repoRoot = fileURLToPath(
    new URL('../../../../../../', import.meta.url)
  );

  it('resolves a dependency copy to an existing file', () => {
    expect(
      tryResolveRobloxSourceFile(
        '[string "ServerScriptService.saveslot.node_modules.@quenty.binder.Shared.Binder"]',
        { repoRoot }
      )
    ).toBe('src/binder/src/Shared/Binder.lua');
  });

  it('resolves a package root module to its init file', () => {
    expect(
      tryResolveRobloxSourceFile(
        '[string "ServerScriptService.studiobridge.node_modules.@quenty.nevermore-test-runner.node_modules.@quenty.loader"]',
        { repoRoot }
      )
    ).toBe('src/loader/src/init.lua');
  });

  it('maps the test slug to the package directory', () => {
    expect(
      tryResolveRobloxSourceFile(
        'ServerScriptService.gameproduct.Server.Cmdr.GameProductCmdrService',
        { repoRoot, packageName: '@quenty/gameproductservice' }
      )
    ).toBe('src/gameproductservice/src/Server/Cmdr/GameProductCmdrService.lua');
  });

  it('rejects vendored, truncated and missing paths', () => {
    for (const instancePath of [
      'ServerScriptService.studiobridge.node_modules.@quenty.nevermore-test-runner.node_modules.@quentystudios.Jest._Index.jsdotlua_promise@3.5.2.promise',
      '[string "ServerScriptService.gameproduct.node_modules.@quenty.playermock.node_modules.@quenty.servic..."]',
      'ServerScriptService.unknownpkg.Shared.Foo',
    ]) {
      expect(tryResolveRobloxSourceFile(instancePath, { repoRoot })).toBe(
        undefined
      );
    }
  });
});
