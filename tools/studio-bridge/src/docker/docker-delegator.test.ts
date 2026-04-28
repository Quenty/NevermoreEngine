import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

// Mock execa and fs before importing the module
vi.mock('execa', () => ({
  execa: vi.fn(),
}));

vi.mock('fs/promises', () => ({
  writeFile: vi.fn().mockResolvedValue(undefined),
  unlink: vi.fn().mockResolvedValue(undefined),
}));

vi.mock('@quenty/cli-output-helpers', () => ({
  OutputHelper: {
    error: vi.fn(),
    warn: vi.fn(),
    info: vi.fn(),
    verbose: vi.fn(),
  },
}));

import { execa } from 'execa';
import {
  shouldDelegateToDockerAsync,
  buildDockerRunArgsAsync,
} from './docker-delegator.js';
import type { ExecuteScriptOptions } from '../cli/script-executor.js';

const mockedExeca = vi.mocked(execa);

describe('shouldDelegateToDockerAsync', () => {
  const originalPlatform = process.platform;

  afterEach(() => {
    vi.restoreAllMocks();
    Object.defineProperty(process, 'platform', { value: originalPlatform });
  });

  it('returns false on non-Linux platforms', async () => {
    Object.defineProperty(process, 'platform', { value: 'darwin' });
    expect(await shouldDelegateToDockerAsync()).toBe(false);
  });

  it('returns false when Wine is available on Linux', async () => {
    Object.defineProperty(process, 'platform', { value: 'linux' });
    mockedExeca.mockResolvedValueOnce({ exitCode: 0 } as any);
    expect(await shouldDelegateToDockerAsync()).toBe(false);
  });

  it('returns true when Wine is missing but Docker is available', async () => {
    Object.defineProperty(process, 'platform', { value: 'linux' });
    mockedExeca.mockRejectedValueOnce(new Error('wine not found'));
    mockedExeca.mockResolvedValueOnce({ exitCode: 0 } as any);
    expect(await shouldDelegateToDockerAsync()).toBe(true);
  });

  it('returns false when neither Wine nor Docker is available', async () => {
    Object.defineProperty(process, 'platform', { value: 'linux' });
    mockedExeca.mockRejectedValueOnce(new Error('wine not found'));
    mockedExeca.mockRejectedValueOnce(new Error('docker not found'));
    expect(await shouldDelegateToDockerAsync()).toBe(false);
  });
});

describe('buildDockerRunArgsAsync', () => {
  const cwd = '/workspace/project';
  const cookie = 'test-cookie';

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('builds correct args for inline script', async () => {
    const options: ExecuteScriptOptions = {
      scriptContent: 'print("hello")',
      packageName: 'studio-bridge',
      timeoutMs: 120_000,
      verbose: false,
      showLogs: true,
    };

    const args = await buildDockerRunArgsAsync(options, cwd, cookie);

    expect(args).toContain('--rm');
    expect(args).toContain('--init');
    expect(args).toContain(`ROBLOSECURITY=${cookie}`);
    expect(args).toContain(`${cwd}:${cwd}`);
    expect(args).toContain(cwd);
    expect(args).toContain('ghcr.io/quenty/nevermore-studio-linux:latest');
    // Inner command should include auth then run
    const bashCmd = args[args.length - 1];
    expect(bashCmd).toContain('studio-bridge linux inject-credentials');
    expect(bashCmd).toContain('studio-bridge process run');
    expect(bashCmd).toContain('--timeout 120000');
    expect(bashCmd).not.toContain('--verbose');
  });

  it('passes --verbose through to inner command', async () => {
    const options: ExecuteScriptOptions = {
      scriptContent: 'print("hello")',
      packageName: 'studio-bridge',
      timeoutMs: 60_000,
      verbose: true,
      showLogs: true,
    };

    const args = await buildDockerRunArgsAsync(options, cwd, cookie);
    const bashCmd = args[args.length - 1];
    expect(bashCmd).toContain('--verbose');
  });

  it('passes --place through when specified', async () => {
    const options: ExecuteScriptOptions = {
      scriptContent: 'print("hello")',
      packageName: 'studio-bridge',
      placePath: '/workspace/project/test.rbxl',
      timeoutMs: 120_000,
      verbose: false,
      showLogs: true,
    };

    const args = await buildDockerRunArgsAsync(options, cwd, cookie);
    const bashCmd = args[args.length - 1];
    expect(bashCmd).toContain('--place /workspace/project/test.rbxl');
  });

  it('uses original file path when filePath is set', async () => {
    const options: ExecuteScriptOptions = {
      scriptContent: 'print("hello")',
      packageName: 'studio-bridge',
      timeoutMs: 120_000,
      verbose: false,
      showLogs: true,
      filePath: '/workspace/project/script.lua',
    };

    const args = await buildDockerRunArgsAsync(options, cwd, cookie);
    const bashCmd = args[args.length - 1];
    expect(bashCmd).toContain('--file /workspace/project/script.lua');
  });

  it('calculates docker timeout with 60s buffer', async () => {
    const options: ExecuteScriptOptions = {
      scriptContent: 'print("hello")',
      packageName: 'studio-bridge',
      timeoutMs: 120_000,
      verbose: false,
      showLogs: true,
    };

    const args = await buildDockerRunArgsAsync(options, cwd, cookie);
    const stopIdx = args.indexOf('--stop-timeout');
    expect(stopIdx).toBeGreaterThan(-1);
    expect(args[stopIdx + 1]).toBe('180'); // (120000 + 60000) / 1000
  });
});
