import { describe, it, expect, vi } from 'vitest';
import { renderResult } from '../../../cli/adapters/cli-command-adapter.js';
import {
  inspectCommand,
  inspectInstanceHandlerAsync,
  type InspectResult,
} from './inspect.js';
import type { InspectedInstance } from '../../../bridge/index.js';

const leaf = { properties: [], attributes: [], childCount: 0 };

function instance(
  name: string,
  className: string,
  fields: Partial<InspectedInstance> = {}
): InspectedInstance {
  return { ...leaf, name, className, path: name, ...fields };
}

function createMockSession(inspected: InspectedInstance) {
  return {
    inspectInstanceAsync: vi.fn().mockResolvedValue({ instance: inspected }),
  } as any;
}

describe('inspectInstanceHandlerAsync', () => {
  it('sends the query, selector and root, reading no values by default', async () => {
    const session = createMockSession(instance('Door', 'Part'));

    await inspectInstanceHandlerAsync(session, {
      query: 'Workspace.Door',
      selector: 'Part',
      root: 'Workspace',
    });

    expect(session.inspectInstanceAsync).toHaveBeenCalledWith({
      query: 'Workspace.Door',
      selector: 'Part',
      root: 'Workspace',
      selection: undefined,
      depth: 0,
      properties: undefined,
      attributes: undefined,
    });
  });

  it('asks for properties, attributes and the selection', async () => {
    const session = createMockSession(instance('Door', 'Part'));

    await inspectInstanceHandlerAsync(session, {
      selection: true,
      properties: true,
      attributes: true,
    });

    expect(session.inspectInstanceAsync).toHaveBeenCalledWith(
      expect.objectContaining({
        selection: true,
        properties: true,
        attributes: true,
      })
    );
  });

  it.each([
    [{}, 0],
    [{ children: true }, 1],
    [{ descendants: true }, 10],
    [{ descendants: true, depth: 3 }, 3],
  ])('turns %o into depth %d', async (flags, depth) => {
    const session = createMockSession(instance('Workspace', 'Workspace'));

    await inspectInstanceHandlerAsync(session, {
      query: 'Workspace',
      ...flags,
    });

    expect(session.inspectInstanceAsync).toHaveBeenCalledWith(
      expect.objectContaining({ depth })
    );
  });

  it('summarizes the instance with no children, its children or its descendants', async () => {
    const summarize = async (inspected: InspectedInstance) =>
      (await inspectInstanceHandlerAsync(createMockSession(inspected), {}))
        .summary;

    expect(await summarize(instance('Terrain', 'Terrain'))).toBe(
      'Terrain, no children'
    );
    expect(
      await summarize(instance('Workspace', 'Workspace', { childCount: 3 }))
    ).toBe('Workspace and 3 children');
    expect(
      await summarize(
        instance('Workspace', 'Workspace', {
          childCount: 1,
          children: [instance('A', 'Part')],
        })
      )
    ).toBe('Workspace and 1 child');
    expect(
      await summarize(
        instance('Workspace', 'Workspace', {
          childCount: 1,
          children: [
            instance('B', 'Model', {
              childCount: 1,
              children: [instance('C', 'Part')],
            }),
          ],
        })
      )
    ).toBe('Workspace and 2 descendants');
  });

  it('summarizes the place top level as its services', async () => {
    const result = await inspectInstanceHandlerAsync(
      createMockSession(
        instance('Place1', 'DataModel', {
          childCount: 2,
          children: [
            instance('Workspace', 'Workspace'),
            instance('Lighting', 'Lighting'),
          ],
        })
      ),
      {}
    );

    expect(result.summary).toBe('2 services');
  });

  it('propagates errors from session', async () => {
    const session = {
      inspectInstanceAsync: vi
        .fn()
        .mockRejectedValue(new Error('Plugin timeout')),
    } as any;

    await expect(
      inspectInstanceHandlerAsync(session, { query: 'Workspace' })
    ).rejects.toThrow('Plugin timeout');
  });
});

describe('inspect --format csv', () => {
  const shown = (name: string, text: string) => ({ name, text, value: text });
  const renderCsv = (instance: InspectedInstance) => {
    const result: InspectResult = { instance, summary: '' };
    return renderResult(inspectCommand, result, 'csv');
  };

  it('writes a row per property and attribute, attributes named @Name', () => {
    const door = instance('Door', 'Part', {
      path: 'Workspace.Door',
      properties: [shown('Anchored', 'true')],
      attributes: [shown('Label', 'a, b')],
    });

    expect(renderCsv(door)).toBe(
      [
        'path,property,value',
        'Workspace.Door,Anchored,true',
        'Workspace.Door,@Label,"a, b"',
        '',
      ].join('\n')
    );
  });

  it('without values, writes the instance and its children, not the place itself', () => {
    const place = instance('Place', 'DataModel', {
      childCount: 1,
      children: [
        instance('Workspace', 'Workspace', {
          childCount: 1,
          children: [instance('Door', 'Part', { path: 'Workspace.Door' })],
        }),
      ],
    });

    expect(renderCsv(place)).toBe(
      ['path,className', 'Workspace,Workspace', 'Workspace.Door,Part', ''].join(
        '\n'
      )
    );
  });
});
