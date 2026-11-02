import { describe, it, expect } from 'vitest';
import { fileURLToPath } from 'url';
import { tryResolveRobloxSourceFile } from './roblox-path-resolver.js';
import { SourcemapResolver } from '../../sourcemap/index.js';
import type { SourcemapNode } from '../../sourcemap/index.js';

const REPO_ROOT = fileURLToPath(new URL('../../../../../../', import.meta.url));

function resolveFile(
  instancePath: string,
  packageName?: string
): string | undefined {
  return tryResolveRobloxSourceFile(instancePath, {
    repoRoot: REPO_ROOT,
    packageName,
  })?.file;
}

describe('tryResolveRobloxSourceFile', () => {
  it('resolves a standard ServerScriptService path', () => {
    expect(
      resolveFile(
        'ServerScriptService.observablecollection.Shared.ObservableList.spec'
      )
    ).toBe('src/observablecollection/src/Shared/ObservableList.spec.lua');
  });

  it('resolves a nested subdirectory path', () => {
    expect(
      resolveFile(
        'ServerScriptService.observablecollection.Shared.SortedList.ObservableSortedList'
      )
    ).toBe(
      'src/observablecollection/src/Shared/SortedList/ObservableSortedList.lua'
    );
  });

  it('handles missing ServerScriptService prefix', () => {
    expect(resolveFile('maid.Shared.MaidTaskUtils.spec')).toBe(
      'src/maid/src/Shared/MaidTaskUtils.spec.lua'
    );
  });

  it('unwraps a chunk-name wrapper', () => {
    expect(
      resolveFile(
        '[string "ServerScriptService.saveslot.Server.HasSaveSlotsDataStore"]'
      )
    ).toBe('src/saveslot/src/Server/HasSaveSlotsDataStore.lua');
  });

  it('maps a nested dependency copy to its own package', () => {
    expect(
      resolveFile(
        'ServerScriptService.saveslot.node_modules.@quenty.adorneedata.node_modules.@quenty.attributeutils.node_modules.@quenty.baseobject.node_modules.@quenty.maid.Shared.Maid'
      )
    ).toBe('src/maid/src/Shared/Maid.lua');
  });

  it('maps a dependency whose folder differs from its npm name', () => {
    expect(
      resolveFile(
        '[string "ServerScriptService.gameproduct.node_modules.@quenty.playermock.Shared.PlayerMock"]'
      )
    ).toBe('src/player-mock/src/Shared/PlayerMock.lua');
  });

  it('resolves a package root module to its init file', () => {
    expect(
      resolveFile(
        '[string "ServerScriptService.studiobridge.node_modules.@quenty.nevermore-test-runner.node_modules.@quenty.loader"]'
      )
    ).toBe('src/loader/src/init.lua');
  });

  it('maps the test slug of the package under test to its folder', () => {
    expect(
      tryResolveRobloxSourceFile(
        'ServerScriptService.gameproduct.Server.Cmdr.GameProductCmdrService',
        { repoRoot: REPO_ROOT, packageName: '@quenty/gameproductservice' }
      )
    ).toEqual({
      file: 'src/gameproductservice/src/Server/Cmdr/GameProductCmdrService.lua',
      isPackageUnderTest: true,
    });
    expect(
      resolveFile(
        'ServerScriptService.playermock.Shared.PlayerMock',
        '@quenty/playermock'
      )
    ).toBe('src/player-mock/src/Shared/PlayerMock.lua');
  });

  it('flags dependency frames as not under test', () => {
    expect(
      tryResolveRobloxSourceFile(
        'ServerScriptService.saveslot.node_modules.@quenty.binder.Shared.Binder',
        { repoRoot: REPO_ROOT, packageName: '@quenty/saveslot' }
      )
    ).toEqual({
      file: 'src/binder/src/Shared/Binder.lua',
      isPackageUnderTest: false,
    });
  });

  it('does not remap a sibling package frame into the package under test', () => {
    expect(
      resolveFile(
        'ServerScriptService.othersibling.Server.SaveSlotService',
        '@quenty/saveslot'
      )
    ).toBeUndefined();
    expect(
      resolveFile('ServerScriptService.Script', '@quenty/saveslot')
    ).toBeUndefined();
  });

  it('rejects vendored, truncated and missing paths', () => {
    for (const instancePath of [
      'ServerScriptService.studiobridge.node_modules.@quenty.nevermore-test-runner.node_modules.@quentystudios.Jest._Index.jsdotlua_promise@3.5.2.promise',
      '[string "ServerScriptService.gameproduct.node_modules.@quenty.playermock.node_modules.@quenty.servic..."]',
      'ServerScriptService.unknownpkg.Shared.Foo',
    ]) {
      expect(resolveFile(instancePath)).toBeUndefined();
    }
  });

  describe('with sourcemap resolver', () => {
    const repoRoot = '/repo';

    const sourcemap: SourcemapNode = {
      name: 'Nevermore',
      className: 'DataModel',
      children: [
        {
          name: 'playermock',
          className: 'Folder',
          filePaths: [`${repoRoot}/src/player-mock/default.project.json`],
          children: [
            {
              name: 'Shared',
              className: 'Folder',
              children: [
                {
                  name: 'PlayerMock',
                  className: 'ModuleScript',
                  filePaths: [
                    `${repoRoot}/src/player-mock/src/Shared/PlayerMock.lua`,
                  ],
                },
              ],
            },
          ],
        },
      ],
    };

    const resolver = SourcemapResolver.fromSourcemap(sourcemap, repoRoot);

    it('looks up dependency copies under their Rojo project name', () => {
      expect(
        tryResolveRobloxSourceFile(
          'ServerScriptService.gameproduct.node_modules.@quenty.playermock.Shared.PlayerMock',
          { repoRoot, sourcemapResolver: resolver }
        )?.file
      ).toBe('src/player-mock/src/Shared/PlayerMock.lua');
    });

    it('returns undefined when neither sourcemap nor repo has the file', () => {
      expect(
        tryResolveRobloxSourceFile(
          'ServerScriptService.unknownpkg.Shared.Foo',
          {
            repoRoot,
            sourcemapResolver: resolver,
          }
        )
      ).toBeUndefined();
    });
  });
});
