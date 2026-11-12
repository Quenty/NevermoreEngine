import { describe, it, expect, vi } from 'vitest';
import {
  argvDependsOnCwd,
  assessHost,
  isServeArgv,
  parseStudioBridgeArgv,
  replaceHostAsync,
  staleHostFromInfo,
} from './stale-host.js';

const ours = {
  version: '0.24.0',
  build: 'aaaaaaaaaaaa',
  packagePath: '/repo/tools/studio-bridge',
};

function hostInfo(overrides: Record<string, unknown> = {}) {
  return {
    version: '0.24.0',
    build: 'bbbbbbbbbbbb',
    packagePath: '/repo/tools/studio-bridge',
    cwd: '/repo',
    pid: 1234,
    argv: ['serve'],
    clients: 1,
    pendingRelays: 0,
    ...overrides,
  } as any;
}

describe('assessHost', () => {
  const action = (overrides: Record<string, unknown>) =>
    assessHost(hostInfo(overrides), ours).action;

  it('replaces an older version, even from another install', () => {
    expect(action({ version: '0.23.5' })).toBe('replace');
    expect(action({ version: '0.23.5', packagePath: '/other' })).toBe(
      'replace'
    );
    expect(action({ version: '0.23.5', build: undefined })).toBe('replace');
  });

  it('replaces another build of this version from this same install', () => {
    expect(action({})).toBe('replace');
  });

  it('only warns about another build of this version from another install', () => {
    expect(action({ packagePath: '/worktree/tools/studio-bridge' })).toBe(
      'warn'
    );
    expect(action({ packagePath: undefined })).toBe('warn');
  });

  it('only warns when either build is unknown at the same version', () => {
    expect(action({ build: undefined })).toBe('warn');
    expect(assessHost(hostInfo(), { ...ours, build: undefined }).action).toBe(
      'warn'
    );
  });

  it('only warns when a version is unknown', () => {
    expect(action({ version: 'unknown' })).toBe('warn');
  });

  it('leaves the same build, or a newer version', () => {
    expect(action({ build: ours.build })).toBe('current');
    expect(action({ version: '0.25.0' })).toBe('current');
  });

  it('orders prerelease versions before their release', () => {
    expect(action({ version: '0.24.0-beta.1' })).toBe('replace');
    expect(
      assessHost(hostInfo(), { ...ours, version: '0.24.0-beta.1' }).action
    ).toBe('current');
  });

  it('replaces a host too old to report itself', () => {
    expect(assessHost(undefined, ours).action).toBe('replace');
  });
});

describe('argvDependsOnCwd', () => {
  it('is false for options without paths', () => {
    expect(argvDependsOnCwd(['serve'])).toBe(false);
    expect(argvDependsOnCwd(['serve', '--port', '38742', '--json'])).toBe(
      false
    );
    expect(argvDependsOnCwd(['--verbose', 'serve', '--timeout=5000'])).toBe(
      false
    );
  });

  it('is true for a positional argument or a path-like option value', () => {
    expect(argvDependsOnCwd(['serve', 'extra'])).toBe(true);
    expect(argvDependsOnCwd(['serve', '--place', 'game.rbxl'])).toBe(true);
    expect(argvDependsOnCwd(['serve', '--place=./game.rbxl'])).toBe(true);
    expect(argvDependsOnCwd(['serve', '--logs', 'out\\logs'])).toBe(true);
  });
});

describe('staleHostFromInfo', () => {
  it('counts the host in use when another client or a relay is active', () => {
    expect(staleHostFromInfo(hostInfo()).inUse).toBe(false);
    expect(staleHostFromInfo(hostInfo({ clients: 2 })).inUse).toBe(true);
    expect(staleHostFromInfo(hostInfo({ pendingRelays: 1 })).inUse).toBe(true);
  });
});

describe('isServeArgv', () => {
  it('recognizes serve with or without options', () => {
    expect(isServeArgv(['serve'])).toBe(true);
    expect(isServeArgv(['--verbose', 'serve', '--port', '38742'])).toBe(true);
    expect(isServeArgv(['console', 'exec', 'serve'])).toBe(false);
    expect(isServeArgv([])).toBe(false);
  });
});

describe('parseStudioBridgeArgv', () => {
  it('reads the arguments after the studio-bridge CLI script', () => {
    expect(
      parseStudioBridgeArgv(
        '"C:\\Program Files\\nodejs\\node.exe" "C:\\Users\\me\\AppData\\Roaming\\npm/node_modules/@quenty/studio-bridge/dist/src/cli/cli.js" serve --port 38742'
      )
    ).toEqual(['serve', '--port', '38742']);
    expect(
      parseStudioBridgeArgv('node /usr/local/bin/studio-bridge serve')
    ).toEqual(['serve']);
  });

  it('is undefined for another program', () => {
    expect(parseStudioBridgeArgv('node vitest run')).toBeUndefined();
  });
});

describe('replaceHostAsync', () => {
  it('stops the old host and starts serve with its arguments', async () => {
    let healthy = true;
    const kill = vi.fn(() => {
      healthy = false;
    });
    const startServe = vi.fn(async () => {
      healthy = true;
      return 5678;
    });

    const pid = await replaceHostAsync(
      38741,
      { pid: 1234, argv: ['serve', '--json'], cwd: '/repo', inUse: false },
      {
        kill,
        startServe,
        isHealthyAsync: async () => healthy,
        delay: async () => {},
      }
    );

    expect(kill).toHaveBeenCalledWith(1234);
    expect(startServe).toHaveBeenCalledWith(['serve', '--json'], '/repo');
    expect(pid).toBe(5678);
  });

  it('fails when the old host does not stop', async () => {
    await expect(
      replaceHostAsync(
        38741,
        { pid: 1234, argv: ['serve'], inUse: false },
        {
          kill: () => {},
          startServe: vi.fn(),
          isHealthyAsync: async () => true,
          delay: async () => {},
        }
      )
    ).rejects.toThrow('did not stop');
  });
});
