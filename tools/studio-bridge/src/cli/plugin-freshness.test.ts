import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  ensureCurrentPluginAsync,
  PluginOutdatedError,
  PLUGIN_UPDATE_FIX,
  resolvePluginUpdatePolicy,
  setPluginUpdatePolicy,
  waitForPluginReloadAsync,
  type PluginFreshnessDeps,
} from './plugin-freshness.js';

function sessionInfo(overrides: Record<string, unknown> = {}) {
  return {
    sessionId: 'place1-ab12-edit',
    instanceId: 'place1-ab12',
    placeName: 'Place1',
    context: 'edit',
    pluginVersion: 'a1b2c3d4e5f6',
    ...overrides,
  } as any;
}

function session(info = sessionInfo()) {
  return { info, context: info.context } as any;
}

function connection(live: () => any[], isRemote = false) {
  return {
    isRemote,
    listSessions: () => live(),
    getSession: (id: string) => {
      const info = live().find((s) => s.sessionId === id);
      return info ? session(info) : undefined;
    },
  } as any;
}

function deps(overrides: Partial<PluginFreshnessDeps> = {}) {
  return {
    getExpectedVersionAsync: async () => 'c3d4e5f6a7b8',
    installAsync: vi.fn(async () => 'installed'),
    confirmAsync: vi.fn(async () => true),
    log: vi.fn(),
    reloadTimeoutMs: 600,
    ...overrides,
  };
}

afterEach(() => {
  setPluginUpdatePolicy('error');
});

describe('resolvePluginUpdatePolicy', () => {
  it('prompts only a person at a terminal', () => {
    expect(
      resolvePluginUpdatePolicy({ stdinIsTTY: true, stderrIsTTY: true })
    ).toBe('prompt');
    expect(
      resolvePluginUpdatePolicy({
        stdinIsTTY: true,
        stderrIsTTY: true,
        json: true,
      })
    ).toBe('error');
    expect(
      resolvePluginUpdatePolicy({ stdinIsTTY: false, stderrIsTTY: true })
    ).toBe('error');
    expect(
      resolvePluginUpdatePolicy({ stdinIsTTY: true, stderrIsTTY: false })
    ).toBe('error');
  });

  it('updates without asking when --update-plugin is passed', () => {
    expect(resolvePluginUpdatePolicy({ updatePlugin: true, json: true })).toBe(
      'update'
    );
  });
});

describe('ensureCurrentPluginAsync', () => {
  it('returns a session whose plugin is current', async () => {
    const current = session(sessionInfo({ pluginVersion: 'c3d4e5f6a7b8' }));
    const d = deps();

    await expect(
      ensureCurrentPluginAsync(
        connection(() => []),
        current,
        d
      )
    ).resolves.toBe(current);
    expect(d.installAsync).not.toHaveBeenCalled();
  });

  it('refuses with a fix an agent can follow', async () => {
    const d = deps();
    const err = await ensureCurrentPluginAsync(
      connection(() => []),
      session(),
      d
    ).catch((e) => e);

    expect(err).toBeInstanceOf(PluginOutdatedError);
    expect(err.code).toBe('PLUGIN_OUTDATED');
    expect(err.message).toBe(
      "The studio-bridge plugin in 'Place1' is out of date."
    );
    expect(err.fix).toBe(PLUGIN_UPDATE_FIX);
    expect(err.cause).toBe(
      'Installed plugin build a1b2c3, this CLI needs c3d4e5'
    );
    expect(d.installAsync).not.toHaveBeenCalled();
  });

  it('asks a person, installs, and waits for the reload', async () => {
    setPluginUpdatePolicy('prompt');
    let live = [sessionInfo()];
    const d = deps({
      installAsync: vi.fn(async () => {
        live = [];
        setTimeout(() => {
          live = [sessionInfo({ pluginVersion: 'c3d4e5f6a7b8' })];
        }, 100);
      }),
    });

    const result = await ensureCurrentPluginAsync(
      connection(() => live),
      session(),
      d
    );

    expect(d.confirmAsync).toHaveBeenCalledWith(
      "The studio-bridge plugin in 'Place1' is out of date.\nUpdate it now? [Y/n] "
    );
    expect(d.installAsync).toHaveBeenCalled();
    expect(result.info.pluginVersion).toBe('c3d4e5f6a7b8');
  });

  it('refuses when the person says no', async () => {
    setPluginUpdatePolicy('prompt');
    const d = deps({ confirmAsync: vi.fn(async () => false) });

    await expect(
      ensureCurrentPluginAsync(
        connection(() => []),
        session(),
        d
      )
    ).rejects.toMatchObject({
      message:
        "Didn't run the command, since the studio-bridge plugin is out of date.",
      fix: "Run 'studio-bridge plugin install' when you want to update it.",
    });
    expect(d.installAsync).not.toHaveBeenCalled();
  });

  it('updates without asking, and says to reopen Studio if it does not reload', async () => {
    setPluginUpdatePolicy('update');
    const d = deps();

    await expect(
      ensureCurrentPluginAsync(
        connection(() => [sessionInfo()]),
        session(),
        d
      )
    ).rejects.toMatchObject({
      code: 'PLUGIN_RELOAD_TIMEOUT',
      fix: "Reopen 'Place1' in Studio, then run the command again.",
    });
    expect(d.confirmAsync).not.toHaveBeenCalled();
    expect(d.installAsync).toHaveBeenCalled();
  });

  it('does not install for a Studio on another machine', async () => {
    setPluginUpdatePolicy('update');
    const d = deps();

    const err = await ensureCurrentPluginAsync(
      connection(() => [], true),
      session(),
      d
    ).catch((e) => e);

    expect(err.fix).toBe(
      "Run 'studio-bridge plugin install' on the machine Studio runs on."
    );
    expect(d.installAsync).not.toHaveBeenCalled();
  });

  it('points a stale playtest session at playtest restart', async () => {
    setPluginUpdatePolicy('update');
    const d = deps();

    const err = await ensureCurrentPluginAsync(
      connection(() => []),
      session(sessionInfo({ context: 'server' })),
      d
    ).catch((e) => e);

    expect(err.fix).toContain('playtest restart');
    expect(d.installAsync).not.toHaveBeenCalled();
  });
});

describe('waitForPluginReloadAsync', () => {
  it('matches a reload that came back under another session id', async () => {
    const reloaded = sessionInfo({
      sessionId: 'place1-ab12-edit-2',
      pluginVersion: 'new',
    });

    const [result] = await waitForPluginReloadAsync(
      connection(() => [reloaded]),
      [sessionInfo()],
      'new',
      100
    );

    expect(result.session?.info.sessionId).toBe('place1-ab12-edit-2');
  });
});
