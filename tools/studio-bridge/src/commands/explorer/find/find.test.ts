import { describe, it, expect, vi } from 'vitest';
import { findInstancesHandlerAsync, formatFindText } from './find.js';

function createSession(result: unknown) {
  return { findInstancesAsync: vi.fn().mockResolvedValue(result) } as any;
}

describe('findInstancesHandlerAsync', () => {
  it('passes the search through and summarizes it', async () => {
    const session = createSession({
      instances: [
        { path: 'Workspace.RedSpawn', name: 'RedSpawn', className: 'Part' },
      ],
      searched: 120,
      truncated: false,
    });

    const result = await findInstancesHandlerAsync(session, {
      name: 'spawn',
      className: 'BasePart',
      exact: true,
    });

    expect(session.findInstancesAsync).toHaveBeenCalledWith({
      name: 'spawn',
      className: 'BasePart',
      exactName: true,
      root: undefined,
      tag: undefined,
      limit: undefined,
    });
    expect(result.summary).toBe('1 match(es) among 120 instances');
    expect(formatFindText(result)).toContain('Workspace.RedSpawn');
  });

  it('says when it stopped at the limit', async () => {
    const session = createSession({
      instances: [{ path: 'Workspace.A', name: 'A', className: 'Part' }],
      searched: 10,
      truncated: true,
    });

    const result = await findInstancesHandlerAsync(session, { tag: 'Spawn' });

    expect(result.summary).toBe('First 1 matches; raise --limit to see more');
  });

  it('needs something to search for', async () => {
    await expect(
      findInstancesHandlerAsync(createSession({}), {})
    ).rejects.toThrow('Give a name, --class or --tag to search for');
  });
});
