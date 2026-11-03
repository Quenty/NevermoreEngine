import { describe, it, expect, vi } from 'vitest';
import { exportInstancesHandlerAsync } from './export.js';

describe('exportInstancesHandlerAsync', () => {
  it('returns the model with its size and the exported paths', async () => {
    const data = Buffer.from('<roblox!model').toString('base64');
    const session = {
      exportInstancesAsync: vi
        .fn()
        .mockResolvedValue({ data, paths: ['Workspace.Map'] }),
    } as any;

    const result = await exportInstancesHandlerAsync(session, [
      'Workspace.Map',
    ]);

    expect(session.exportInstancesAsync).toHaveBeenCalledWith([
      'Workspace.Map',
    ]);
    expect(result).toEqual({
      data,
      paths: ['Workspace.Map'],
      bytes: 13,
      summary: 'Exported 1 instance(s) (13 bytes): Workspace.Map',
    });
  });
});
