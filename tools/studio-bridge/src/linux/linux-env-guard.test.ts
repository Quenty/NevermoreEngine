import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('os', () => ({
  platform: vi.fn(),
}));

vi.mock('child_process', () => ({
  execFile: vi.fn(),
}));

vi.mock('util', () => ({
  promisify: (fn: any) => fn,
}));

import { platform } from 'os';
import { execFile } from 'child_process';
import { checkLinuxEnvironmentAsync } from './linux-env-guard.js';

const mockPlatform = vi.mocked(platform);
const mockExecFile = vi.mocked(execFile);

describe('checkLinuxEnvironmentAsync', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it('returns an error message on non-Linux platforms', async () => {
    mockPlatform.mockReturnValue('win32');

    const result = await checkLinuxEnvironmentAsync();

    expect(result).toBeDefined();
    expect(result).toContain('linux commands require a Linux environment');
    expect(result).toContain('studio-bridge process run');
    expect(mockExecFile).not.toHaveBeenCalled();
  });

  it('returns undefined when on Linux with Wine installed', async () => {
    mockPlatform.mockReturnValue('linux');
    mockExecFile.mockResolvedValue({ stdout: '/usr/bin/wine\n', stderr: '' } as any);

    const result = await checkLinuxEnvironmentAsync();

    expect(result).toBeUndefined();
    expect(mockExecFile).toHaveBeenCalledWith('which', ['wine']);
  });

  it('returns an error message on Linux without Wine', async () => {
    mockPlatform.mockReturnValue('linux');
    mockExecFile.mockRejectedValue(new Error('not found'));

    const result = await checkLinuxEnvironmentAsync();

    expect(result).toBeDefined();
    expect(result).toContain('Wine is not installed');
    expect(result).toContain('studio-bridge process run');
    expect(result).toContain('docker run');
  });
});
