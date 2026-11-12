import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { afterEach, beforeEach, describe, it, expect } from 'vitest';
import {
  findInstancesShowingPlaceAsync,
  tryFindFolderInstanceAsync,
} from './deploy-places.js';

let tempDir: string;

beforeEach(async () => {
  tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'deploy-places-test-'));
  await fs.writeFile(
    path.join(tempDir, 'deploy.nevermore.json'),
    JSON.stringify({
      targets: {
        test: { universeId: 9, placeId: 111, project: 'test.project.json' },
        integration: {
          places: [
            {
              name: 'hub',
              universeId: 9,
              placeId: 222,
              project: 'hub.project.json',
            },
          ],
        },
      },
    })
  );
});

afterEach(async () => {
  await fs.rm(tempDir, { recursive: true, force: true });
});

/** Studios by instance id, with the place id each registered and the one each has open now. */
function createConnection(
  studios: Record<string, { registered: number; live: number }>
) {
  const ids = Object.keys(studios);
  return {
    listInstances: () =>
      ids.map((instanceId) => ({
        instanceId,
        placeId: studios[instanceId].registered,
      })),
    listSessions: () =>
      ids.map((instanceId) => ({
        instanceId,
        sessionId: `${instanceId}-edit`,
        context: 'edit',
      })),
    getSession: (sessionId: string) => ({
      queryStateAsync: async () => ({
        placeId: studios[sessionId.replace(/-edit$/, '')].live,
      }),
    }),
  } as any;
}

describe('tryFindFolderInstanceAsync', () => {
  it("picks the one Studio that has a place of the folder's config open", async () => {
    const connection = createConnection({
      'local-1a2b': { registered: 0, live: 0 },
      'place1-3c4d': { registered: 0, live: 222 },
    });

    const found = await tryFindFolderInstanceAsync(connection, tempDir);

    expect(found?.instanceId).toBe('place1-3c4d');
    expect(found?.deployPlace.selector).toBe('integration');
  });

  it('leaves the choice alone when two Studios have the config open', async () => {
    const connection = createConnection({
      'place1-1a2b': { registered: 111, live: 111 },
      'place1-3c4d': { registered: 222, live: 222 },
    });

    expect(
      await tryFindFolderInstanceAsync(connection, tempDir)
    ).toBeUndefined();
  });

  it('leaves a single Studio to the usual resolution', async () => {
    const connection = createConnection({
      'local-1a2b': { registered: 0, live: 0 },
    });

    expect(
      await tryFindFolderInstanceAsync(connection, tempDir)
    ).toBeUndefined();
  });

  it('does nothing outside a deploy.nevermore.json', async () => {
    const empty = await fs.mkdtemp(
      path.join(os.tmpdir(), 'deploy-places-empty-')
    );
    const connection = createConnection({
      'place1-1a2b': { registered: 111, live: 111 },
      'local-3c4d': { registered: 0, live: 0 },
    });

    try {
      expect(
        await tryFindFolderInstanceAsync(connection, empty)
      ).toBeUndefined();
    } finally {
      await fs.rm(empty, { recursive: true, force: true });
    }
  });
});

describe('findInstancesShowingPlaceAsync', () => {
  it('reads a cloud place id live when it registered as 0', async () => {
    const connection = createConnection({
      'place1-1a2b': { registered: 0, live: 111 },
      'place1-3c4d': { registered: 222, live: 222 },
    });

    expect(await findInstancesShowingPlaceAsync(connection, 111)).toEqual([
      'place1-1a2b',
    ]);
  });
});
