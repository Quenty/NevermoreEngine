import { describe, it, expect, vi } from 'vitest';
import { exportInstancesHandlerAsync } from './export.js';

const MAP = {
  path: 'Workspace.Map',
  segments: ['Workspace', 'Map'],
  className: 'Model',
};

describe('exportInstancesHandlerAsync', () => {
  it('returns the model with its size and the exported instances', async () => {
    const data = Buffer.from('<roblox!model').toString('base64');
    const session = {
      exportInstancesAsync: vi
        .fn()
        .mockResolvedValue({ data, instances: [MAP] }),
    } as any;

    const result = await exportInstancesHandlerAsync(session, [
      'Workspace.Map',
    ]);

    expect(session.exportInstancesAsync).toHaveBeenCalledWith([
      'Workspace.Map',
    ]);
    expect(result).toEqual({
      data,
      instances: [MAP],
      bytes: 13,
      summary: 'Exported 1 instance (13 bytes)',
    });
  });
});
