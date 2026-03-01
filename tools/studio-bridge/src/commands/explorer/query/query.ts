/**
 * `explorer query` — query the Roblox DataModel instance tree from a
 * connected Studio session.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { BridgeSession } from '../../../bridge/index.js';
import type {
  DataModelResult as BridgeDataModelResult,
  DataModelInstance,
} from '../../../bridge/index.js';

export type { DataModelInstance };

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface QueryOptions {
  path: string;
  children?: boolean;
  descendants?: boolean;
  depth?: number;
  properties?: boolean;
  attributes?: boolean;
}

export interface DataModelNode {
  name: string;
  className: string;
  path: string;
  properties?: Record<string, unknown>;
  attributes?: Record<string, unknown>;
  children?: DataModelNode[];
}

export interface QueryResult {
  node: DataModelNode;
  summary: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function normalizePath(path: string): string {
  if (path.startsWith('game.') || path === 'game') {
    return path;
  }
  return `game.${path}`;
}

function toDataModelNode(instance: DataModelInstance): DataModelNode {
  const node: DataModelNode = {
    name: instance.name,
    className: instance.className,
    path: instance.path,
  };

  if (instance.properties && Object.keys(instance.properties).length > 0) {
    node.properties = instance.properties;
  }

  if (instance.attributes && Object.keys(instance.attributes).length > 0) {
    node.attributes = instance.attributes;
  }

  if (instance.children && instance.children.length > 0) {
    node.children = instance.children.map(toDataModelNode);
  }

  return node;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function queryDataModelHandlerAsync(
  session: BridgeSession,
  options: QueryOptions,
): Promise<QueryResult> {
  const normalizedPath = normalizePath(options.path);

  const depth = options.descendants
    ? (options.depth ?? 10)
    : options.children
      ? 1
      : 0;

  const result: BridgeDataModelResult = await session.queryDataModelAsync({
    path: normalizedPath,
    depth,
    properties: options.properties ? undefined : [],
    includeAttributes: options.attributes,
  });

  if (!result.instance) {
    throw new Error(`Instance not found at path '${options.path}'`);
  }

  const node = toDataModelNode(result.instance);

  return {
    node,
    summary: `${node.name} (${node.className}) at ${node.path}`,
  };
}

// ---------------------------------------------------------------------------
// Formatters
// ---------------------------------------------------------------------------

function formatNode(node: DataModelNode, depth: number): string {
  const indent = '  '.repeat(depth);
  const lines = [`${indent}${node.name} (${OutputHelper.formatDim(node.className)}) ${OutputHelper.formatDim(node.path)}`];
  if (node.properties) {
    for (const [key, val] of Object.entries(node.properties)) {
      lines.push(`${indent}  ${key}: ${JSON.stringify(val)}`);
    }
  }
  if (node.attributes) {
    for (const [key, val] of Object.entries(node.attributes)) {
      lines.push(`${indent}  @${key}: ${JSON.stringify(val)}`);
    }
  }
  for (const child of node.children ?? []) {
    lines.push(formatNode(child, depth + 1));
  }
  return lines.join('\n');
}

export function formatQueryText(result: QueryResult): string {
  return formatNode(result.node, 0);
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const queryCommand = defineCommand<QueryOptions, QueryResult>({
  group: 'explorer',
  name: 'query',
  description: 'Query the Roblox DataModel instance tree',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {
    path: arg.positional({ description: 'DataModel path (e.g. "Workspace" or "game.Workspace")' }),
    depth: arg.option({ description: 'Levels of descendants to include', type: 'number' }),
    properties: arg.flag({ description: 'Include instance properties' }),
    attributes: arg.flag({ description: 'Include instance attributes' }),
    children: arg.flag({ description: 'Include direct children' }),
    descendants: arg.flag({ description: 'Include all descendants' }),
  },
  cli: {
    formatResult: {
      text: formatQueryText,
      table: formatQueryText,
    },
  },
  handler: async (session, args) => {
    return queryDataModelHandlerAsync(session, args);
  },
  mcp: {
    mapInput: (input) => ({
      path: input.path as string,
      depth: input.depth as number | undefined,
      properties: input.properties !== undefined ? true : undefined,
      attributes: input.includeAttributes as boolean | undefined,
      children: input.children as boolean | undefined,
    }),
    mapResult: (result) => [
      {
        type: 'text' as const,
        text: JSON.stringify({ node: result.node }),
      },
    ],
  },
});
