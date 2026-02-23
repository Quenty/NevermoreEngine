/**
 * Handler for the `query` command. Queries the Roblox DataModel instance
 * tree from a connected Studio session, returning node info with optional
 * children, properties, and attributes.
 */

import type { BridgeSession } from '../bridge/index.js';
import type { DataModelResult as BridgeDataModelResult, DataModelInstance } from '../bridge/index.js';

export type { DataModelInstance };

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

/**
 * Normalize a path to ensure it starts with "game.".
 */
function normalizePath(path: string): string {
  if (path.startsWith('game.') || path === 'game') {
    return path;
  }
  return `game.${path}`;
}

/**
 * Convert a BridgeSession DataModelInstance to a DataModelNode.
 */
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

/**
 * Query the DataModel instance tree from a connected Studio session.
 */
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

  const node = toDataModelNode(result.instance);

  return {
    node,
    summary: `${node.name} (${node.className}) at ${node.path}`,
  };
}
