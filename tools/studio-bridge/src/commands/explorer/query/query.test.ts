/**
 * Unit tests for the query command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import { queryDataModelHandlerAsync } from './query.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockSession(dataModelResult: {
  instance: {
    name: string;
    className: string;
    path: string;
    properties: Record<string, unknown>;
    attributes: Record<string, unknown>;
    childCount: number;
    children?: Array<{
      name: string;
      className: string;
      path: string;
      properties: Record<string, unknown>;
      attributes: Record<string, unknown>;
      childCount: number;
    }>;
  };
}) {
  return {
    queryDataModelAsync: vi.fn().mockResolvedValue(dataModelResult),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('queryDataModelHandlerAsync', () => {
  it('returns node with summary', async () => {
    const session = createMockSession({
      instance: {
        name: 'SpawnLocation',
        className: 'SpawnLocation',
        path: 'game.Workspace.SpawnLocation',
        properties: { Anchored: true },
        attributes: {},
        childCount: 0,
      },
    });

    const result = await queryDataModelHandlerAsync(session, {
      path: 'Workspace.SpawnLocation',
    });

    expect(result.node.name).toBe('SpawnLocation');
    expect(result.node.className).toBe('SpawnLocation');
    expect(result.node.path).toBe('game.Workspace.SpawnLocation');
    expect(result.summary).toContain('SpawnLocation');
    expect(result.summary).toContain('game.Workspace.SpawnLocation');
  });

  it('prepends game. to path when not present', async () => {
    const session = createMockSession({
      instance: {
        name: 'Workspace',
        className: 'Workspace',
        path: 'game.Workspace',
        properties: {},
        attributes: {},
        childCount: 5,
      },
    });

    await queryDataModelHandlerAsync(session, { path: 'Workspace' });

    expect(session.queryDataModelAsync).toHaveBeenCalledWith(
      expect.objectContaining({ path: 'game.Workspace' }),
    );
  });

  it('does not double-prepend game. when already present', async () => {
    const session = createMockSession({
      instance: {
        name: 'Workspace',
        className: 'Workspace',
        path: 'game.Workspace',
        properties: {},
        attributes: {},
        childCount: 0,
      },
    });

    await queryDataModelHandlerAsync(session, { path: 'game.Workspace' });

    expect(session.queryDataModelAsync).toHaveBeenCalledWith(
      expect.objectContaining({ path: 'game.Workspace' }),
    );
  });

  it('passes children option as depth 1', async () => {
    const session = createMockSession({
      instance: {
        name: 'Workspace',
        className: 'Workspace',
        path: 'game.Workspace',
        properties: {},
        attributes: {},
        childCount: 2,
        children: [
          {
            name: 'Part1',
            className: 'Part',
            path: 'game.Workspace.Part1',
            properties: {},
            attributes: {},
            childCount: 0,
          },
          {
            name: 'Part2',
            className: 'Part',
            path: 'game.Workspace.Part2',
            properties: {},
            attributes: {},
            childCount: 0,
          },
        ],
      },
    });

    const result = await queryDataModelHandlerAsync(session, {
      path: 'Workspace',
      children: true,
    });

    expect(session.queryDataModelAsync).toHaveBeenCalledWith(
      expect.objectContaining({ depth: 1 }),
    );
    expect(result.node.children).toHaveLength(2);
    expect(result.node.children![0].name).toBe('Part1');
    expect(result.node.children![1].name).toBe('Part2');
  });

  it('passes descendants option with default depth', async () => {
    const session = createMockSession({
      instance: {
        name: 'Workspace',
        className: 'Workspace',
        path: 'game.Workspace',
        properties: {},
        attributes: {},
        childCount: 0,
      },
    });

    await queryDataModelHandlerAsync(session, {
      path: 'Workspace',
      descendants: true,
    });

    expect(session.queryDataModelAsync).toHaveBeenCalledWith(
      expect.objectContaining({ depth: 10 }),
    );
  });

  it('respects explicit depth with descendants', async () => {
    const session = createMockSession({
      instance: {
        name: 'Workspace',
        className: 'Workspace',
        path: 'game.Workspace',
        properties: {},
        attributes: {},
        childCount: 0,
      },
    });

    await queryDataModelHandlerAsync(session, {
      path: 'Workspace',
      descendants: true,
      depth: 3,
    });

    expect(session.queryDataModelAsync).toHaveBeenCalledWith(
      expect.objectContaining({ depth: 3 }),
    );
  });

  it('includes properties when requested', async () => {
    const session = createMockSession({
      instance: {
        name: 'Part1',
        className: 'Part',
        path: 'game.Workspace.Part1',
        properties: {
          Anchored: true,
          Position: { type: 'Vector3', value: [0, 5, 0] },
        },
        attributes: {},
        childCount: 0,
      },
    });

    const result = await queryDataModelHandlerAsync(session, {
      path: 'Workspace.Part1',
      properties: true,
    });

    expect(result.node.properties).toBeDefined();
    expect(result.node.properties!['Anchored']).toBe(true);
  });

  it('includes attributes when requested', async () => {
    const session = createMockSession({
      instance: {
        name: 'Part1',
        className: 'Part',
        path: 'game.Workspace.Part1',
        properties: {},
        attributes: { health: 100, tag: 'enemy' },
        childCount: 0,
      },
    });

    const result = await queryDataModelHandlerAsync(session, {
      path: 'Workspace.Part1',
      attributes: true,
    });

    expect(result.node.attributes).toBeDefined();
    expect(result.node.attributes!['health']).toBe(100);
    expect(result.node.attributes!['tag']).toBe('enemy');
  });

  it('omits empty properties and attributes from node', async () => {
    const session = createMockSession({
      instance: {
        name: 'Folder',
        className: 'Folder',
        path: 'game.Workspace.Folder',
        properties: {},
        attributes: {},
        childCount: 0,
      },
    });

    const result = await queryDataModelHandlerAsync(session, {
      path: 'Workspace.Folder',
    });

    expect(result.node.properties).toBeUndefined();
    expect(result.node.attributes).toBeUndefined();
    expect(result.node.children).toBeUndefined();
  });

  it('propagates errors from session', async () => {
    const session = {
      queryDataModelAsync: vi.fn().mockRejectedValue(new Error('Instance not found')),
    } as any;

    await expect(
      queryDataModelHandlerAsync(session, { path: 'Workspace.NonExistent' }),
    ).rejects.toThrow('Instance not found');
  });

  it('handles path "game" as standalone', async () => {
    const session = createMockSession({
      instance: {
        name: 'Game',
        className: 'DataModel',
        path: 'game',
        properties: {},
        attributes: {},
        childCount: 10,
      },
    });

    await queryDataModelHandlerAsync(session, { path: 'game' });

    expect(session.queryDataModelAsync).toHaveBeenCalledWith(
      expect.objectContaining({ path: 'game' }),
    );
  });

  it('without children or descendants uses depth 0', async () => {
    const session = createMockSession({
      instance: {
        name: 'Workspace',
        className: 'Workspace',
        path: 'game.Workspace',
        properties: {},
        attributes: {},
        childCount: 5,
      },
    });

    await queryDataModelHandlerAsync(session, { path: 'Workspace' });

    expect(session.queryDataModelAsync).toHaveBeenCalledWith(
      expect.objectContaining({ depth: 0 }),
    );
  });
});
