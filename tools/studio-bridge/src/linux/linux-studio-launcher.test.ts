import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.mock('fs', () => ({
  openSync: vi.fn(() => 7),
  closeSync: vi.fn(),
}));

vi.mock('os', () => ({
  tmpdir: vi.fn(() => '/tmp'),
}));

vi.mock('child_process', () => ({
  spawn: vi.fn(),
}));

vi.mock('@quenty/cli-output-helpers', () => ({
  OutputHelper: { verbose: vi.fn() },
}));

vi.mock('./linux-config.js', () => ({
  resolveLinuxConfig: vi.fn(() => ({ display: ':99' })),
}));

vi.mock('./linux-wine-env.js', () => ({
  buildWineEnv: vi.fn(() => ({ DISPLAY: ':99' })),
}));

vi.mock('./linux-display-manager.js', () => ({
  ensureDisplayAsync: vi.fn(async () => undefined),
  ensureWindowManagerAsync: vi.fn(async () => undefined),
}));

import { spawn } from 'child_process';
import { launchStudioLinuxAsync } from './linux-studio-launcher.js';

const mockSpawn = vi.mocked(spawn);

function makeFakeProc() {
  return {
    on: vi.fn(),
    unref: vi.fn(),
    kill: vi.fn(),
    stdout: { on: vi.fn(), unref: vi.fn() },
  };
}

describe('launchStudioLinuxAsync', () => {
  let wineProc: ReturnType<typeof makeFakeProc>;
  let tailProc: ReturnType<typeof makeFakeProc>;

  beforeEach(() => {
    vi.clearAllMocks();
    wineProc = makeFakeProc();
    tailProc = makeFakeProc();
    mockSpawn.mockImplementation(((cmd: string) =>
      cmd === 'tail' ? tailProc : wineProc) as never);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('unrefs the tail stdout pipe so the CLI can exit', async () => {
    await launchStudioLinuxAsync('/studio/Studio.exe', '/place.rbxl');

    expect(tailProc.unref).toHaveBeenCalled();
    expect(tailProc.stdout.unref).toHaveBeenCalled();
  });

  it('reaps the tail process when the CLI exits', async () => {
    const onceSpy = vi.spyOn(process, 'once');

    await launchStudioLinuxAsync('/studio/Studio.exe', '/place.rbxl');

    const exitHandler = onceSpy.mock.calls.find(([evt]) => evt === 'exit')?.[1];
    expect(exitHandler).toBeTypeOf('function');

    (exitHandler as () => void)();
    expect(tailProc.kill).toHaveBeenCalledWith('SIGTERM');
  });

  it('does not unref the detached Studio process stdio', async () => {
    await launchStudioLinuxAsync('/studio/Studio.exe', '/place.rbxl');

    expect(wineProc.unref).toHaveBeenCalled();
    const wineCall = mockSpawn.mock.calls.find(([cmd]) => cmd === 'wine');
    expect((wineCall?.[2] as { detached?: boolean })?.detached).toBe(true);
  });
});
