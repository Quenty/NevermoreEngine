import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  autoStartHostAsync,
  describeAutoHostFailure,
  getAutoHostArgv,
  HostNotListeningError,
  shouldAutoStartHost,
  tryAutoStartHostAsync,
} from './auto-host.js';
import {
  BackgroundStartError,
  isServeArgv,
  startServeInBackgroundAsync,
} from './stale-host.js';
import {
  clearWarnings,
  createFileStore,
  ONE_DAY_MS,
  setShownWarningsStore,
} from '../../messages/warn-user.js';

describe('shouldAutoStartHost', () => {
  beforeEach(() => {
    vi.stubEnv('GITHUB_ACTIONS', '');
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it('starts a host by default', () => {
    expect(shouldAutoStartHost(undefined, {})).toBe(true);
    expect(shouldAutoStartHost(true, {})).toBe(true);
  });

  it('does not in CI', () => {
    vi.stubEnv('GITHUB_ACTIONS', 'true');
    expect(shouldAutoStartHost(true, {})).toBe(false);
  });

  it('does not with --no-autohost', () => {
    expect(shouldAutoStartHost(false, {})).toBe(false);
  });

  it('does not with STUDIO_BRIDGE_NO_AUTOHOST set', () => {
    expect(shouldAutoStartHost(true, { STUDIO_BRIDGE_NO_AUTOHOST: '1' })).toBe(
      false
    );
    expect(
      shouldAutoStartHost(undefined, { STUDIO_BRIDGE_NO_AUTOHOST: 'true' })
    ).toBe(false);
  });

  it('ignores STUDIO_BRIDGE_NO_AUTOHOST turned off', () => {
    expect(
      shouldAutoStartHost(undefined, { STUDIO_BRIDGE_NO_AUTOHOST: '0' })
    ).toBe(true);
    expect(
      shouldAutoStartHost(undefined, { STUDIO_BRIDGE_NO_AUTOHOST: '' })
    ).toBe(true);
  });
});

describe('getAutoHostArgv', () => {
  it('runs serve with an idle timeout, which stale-host replacement can restart', () => {
    const argv = getAutoHostArgv(38741);

    expect(argv).toEqual([
      'serve',
      '--port',
      '38741',
      '--idle-timeout',
      '10m',
      '--auto-started',
    ]);
    expect(isServeArgv(argv)).toBe(true);
  });
});

describe('autoStartHostAsync', () => {
  it('starts serve and resolves once a host answers', async () => {
    const startServe = vi.fn().mockResolvedValue(4242);
    let checks = 0;
    const pid = await autoStartHostAsync(38741, {
      startServe,
      isHealthyAsync: async () => ++checks >= 3,
      delay: async () => {},
    });

    expect(pid).toBe(4242);
    expect(startServe).toHaveBeenCalledWith(
      getAutoHostArgv(38741),
      expect.any(String)
    );
    expect(checks).toBe(3);
  });

  it('resolves when another command started the host that answers', async () => {
    const pid = await autoStartHostAsync(38741, {
      startServe: async () => 1,
      isHealthyAsync: async () => true,
      delay: async () => {},
    });

    expect(pid).toBe(1);
  });

  it('throws when no host ever answers', async () => {
    await expect(
      autoStartHostAsync(38741, {
        startServe: async () => 1,
        isHealthyAsync: async () => false,
        delay: async () => {},
      })
    ).rejects.toBeInstanceOf(HostNotListeningError);
  });
});

describe('auto-host start failures', () => {
  const logPath = '/state/host-38741.log';
  let stateDir: string;
  let now: number;
  let warn: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    stateDir = fs.mkdtempSync(path.join(os.tmpdir(), 'auto-host-'));
    now = Date.UTC(2026, 10, 11, 9);
    setShownWarningsStore(
      createFileStore(path.join(stateDir, 'shown-warnings.json')),
      () => now
    );
    warn = vi.spyOn(OutputHelper, 'warn').mockImplementation(() => {});
    vi.spyOn(OutputHelper, 'hint').mockImplementation(() => {});
    vi.spyOn(OutputHelper, 'isVerbose').mockReturnValue(false);
  });

  afterEach(() => {
    clearWarnings();
    vi.restoreAllMocks();
    fs.rmSync(stateDir, { recursive: true, force: true });
  });

  const failingStart = (error: Error) => ({
    startServe: async () => {
      throw error;
    },
    isHealthyAsync: async () => false,
    delay: async () => {},
  });

  it('says PowerShell failed, without its command line', () => {
    const warning = describeAutoHostFailure(
      new BackgroundStartError(
        'powershell-failed',
        'powershell.exe failed: Command failed with ENOENT: powershell.exe -NoProfile -NonInteractive -Command $s = New-CimInstance ...'
      ),
      logPath
    );

    expect(warning.message).toBe(
      "Couldn't start a background bridge host (PowerShell failed to run), so each command hosts the bridge itself and takes a few seconds longer."
    );
    expect(warning.fix).toBe(
      "Run 'studio-bridge serve' in another terminal instead."
    );
    expect(warning.message).not.toContain('NoProfile');
    expect(warning.oncePerMs).toBe(ONE_DAY_MS);
  });

  it('says Windows did not start it when no process id comes back', () => {
    const warning = describeAutoHostFailure(
      new BackgroundStartError('no-pid', 'no process id'),
      logPath
    );

    expect(warning.message).toContain("(Windows didn't start it)");
    expect(String(warning.cause)).not.toContain(logPath);
  });

  it('names the log only when the host started and the log exists', () => {
    const notListening = new HostNotListeningError(38741);

    const withLog = describeAutoHostFailure(notListening, logPath, () => true);
    const withoutLog = describeAutoHostFailure(
      notListening,
      logPath,
      () => false
    );

    expect(withLog.message).toContain('(it started but never answered)');
    expect(withLog.fix).toBe(
      "Run 'studio-bridge serve' in another terminal to see why it fails."
    );
    expect(String(withLog.cause)).toContain(logPath);
    expect(withLog.message).not.toContain(logPath);
    expect(withoutLog.cause).toBe(notListening);
  });

  it.runIf(process.platform === 'win32')(
    'reports a PowerShell that cannot run as its own failure',
    async () => {
      const err = await startServeInBackgroundAsync(['serve'], stateDir, {
        powershell: path.join(stateDir, 'missing', 'powershell.exe'),
      }).catch((e) => e);

      expect(err).toBeInstanceOf(BackgroundStartError);
      expect(err.failure).toBe('powershell-failed');
    }
  );

  it('warns once a day when PowerShell keeps failing, and the command goes on', async () => {
    const powershellFailed = new BackgroundStartError(
      'powershell-failed',
      'powershell.exe failed'
    );

    expect(
      await tryAutoStartHostAsync(38741, failingStart(powershellFailed))
    ).toBe(false);
    clearWarnings();
    now += 60 * 60 * 1000;
    expect(
      await tryAutoStartHostAsync(38741, failingStart(powershellFailed))
    ).toBe(false);

    expect(warn).toHaveBeenCalledTimes(1);
  });
});
