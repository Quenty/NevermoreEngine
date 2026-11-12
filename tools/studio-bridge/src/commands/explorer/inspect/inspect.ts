import {
  formatCount,
  formatTree,
  type TreeNode,
} from '@quenty/cli-output-helpers/reporting';
import {
  defineCommand,
  type ResultTable,
} from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type {
  BridgeSession,
  InspectedInstance,
} from '../../../bridge/index.js';
import type { ShownValue } from '../../../server/web-socket-protocol.js';
import {
  removedSelectionOptions,
  selectionArgs,
  toInstanceQuery,
  type InstanceQuery,
  type SelectionArgs,
} from '../selection-args.js';

export type { InspectedInstance };

const MAX_VALUE_LENGTH = 120;

export interface InspectOptions
  extends Pick<InstanceQuery, 'root' | 'query' | 'selector'> {
  selection?: boolean;
  children?: boolean;
  descendants?: boolean;
  depth?: number;
  properties?: boolean;
  attributes?: boolean;
}

export interface InspectResult {
  instance: InspectedInstance;
  summary: string;
}

export async function inspectInstanceHandlerAsync(
  session: BridgeSession,
  options: InspectOptions
): Promise<InspectResult> {
  const depth =
    options.depth !== undefined
      ? options.depth
      : options.descendants
      ? 10
      : options.children
      ? 1
      : 0;

  const result = await session.inspectInstanceAsync({
    root: options.root,
    query: options.query,
    selector: options.selector,
    selection: options.selection || undefined,
    depth,
    properties: options.properties || undefined,
    attributes: options.attributes || undefined,
  });

  return { instance: result.instance, summary: summarize(result.instance) };
}

function summarize(instance: InspectedInstance): string {
  const descendants = countDescendants(instance);
  const below = descendants - (instance.children?.length ?? 0);
  if (isPlace(instance)) {
    const services = formatCount(instance.childCount, 'service', 'services');
    return below > 0
      ? `${services} and ${formatCount(below, 'descendant', 'descendants')}`
      : services;
  }

  if (instance.childCount === 0) {
    return `${instance.name}, no children`;
  }
  return below > 0
    ? `${instance.name} and ${formatCount(
        descendants,
        'descendant',
        'descendants'
      )}`
    : `${instance.name} and ${formatCount(
        instance.childCount,
        'child',
        'children'
      )}`;
}

function isPlace(instance: InspectedInstance): boolean {
  return instance.className === 'DataModel';
}

function countDescendants(instance: InspectedInstance): number {
  return (instance.children ?? []).reduce(
    (sum, child) => sum + 1 + countDescendants(child),
    0
  );
}

function toTreeNode(instance: InspectedInstance): TreeNode {
  return {
    label: instance.name,
    annotation:
      instance.className === instance.name ? undefined : instance.className,
    isMatch: true,
    children: [
      ...instance.properties.map((shown) => toValueNode(shown.name, shown)),
      ...instance.attributes.map((shown) =>
        toValueNode(`@${shown.name}`, shown)
      ),
      ...(instance.children ?? []).map(toTreeNode),
    ],
  };
}

function toValueNode(label: string, shown: ShownValue): TreeNode {
  const text = shown.text.replace(/\r?\n/g, '\\n');
  return {
    label: `${label}: ${
      text.length > MAX_VALUE_LENGTH
        ? `${text.slice(0, MAX_VALUE_LENGTH - 1)}…`
        : text
    }`,
  };
}

export function formatInspectText({ instance }: InspectResult): string {
  return formatTree(
    isPlace(instance)
      ? (instance.children ?? []).map(toTreeNode)
      : [toTreeNode(instance)]
  );
}

function listInspected(instance: InspectedInstance): InspectedInstance[] {
  return [instance, ...(instance.children ?? []).flatMap(listInspected)];
}

function hasShownValues(instance: InspectedInstance): boolean {
  return instance.properties.length > 0 || instance.attributes.length > 0;
}

export function toInspectTable({ instance }: InspectResult): ResultTable {
  const instances = isPlace(instance)
    ? (instance.children ?? []).flatMap(listInspected)
    : listInspected(instance);
  if (!instances.some(hasShownValues)) {
    return {
      columns: ['path', 'className'],
      rows: instances.map((shown) => [shown.path, shown.className]),
    };
  }
  return {
    columns: ['path', 'property', 'value'],
    rows: instances.flatMap((shown) => [
      ...shown.properties.map((property) => [
        shown.path,
        property.name,
        property.text,
      ]),
      ...shown.attributes.map((attribute) => [
        shown.path,
        `@${attribute.name}`,
        attribute.text,
      ]),
    ]),
  };
}

interface InspectArgs extends SelectionArgs {
  selection?: boolean;
  depth?: number;
  properties?: boolean;
  attributes?: boolean;
  children?: boolean;
  descendants?: boolean;
}

export const inspectCommand = defineCommand<InspectArgs, InspectResult>({
  group: 'explorer',
  name: 'inspect',
  description:
    'Read one instance, picked out as explorer find does: its children, descendants, properties and attributes. Without a query, the place top level',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {
    ...selectionArgs,
    query: {
      ...selectionArgs.query,
      description: `${selectionArgs.query.description}. Must match one instance; quote a name with dots in a path (_Index."pkg@1.2.3".pkg). Default: the place's services`,
    },
    selection: arg.flag({
      description: 'Inspect the instance selected in Studio',
    }),
    depth: arg.option({
      description: 'Levels of descendants to include',
      type: 'number',
    }),
    properties: arg.flag({
      description: 'Include every property the plugin can read, sorted by name',
    }),
    attributes: arg.flag({ description: 'Include instance attributes' }),
    children: arg.flag({ description: 'Include direct children' }),
    descendants: arg.flag({ description: 'Include all descendants' }),
  },
  cli: {
    body: formatInspectText,
    rows: toInspectTable,
    removedOptions: removedSelectionOptions,
    hiddenAliases: ['query'],
  },
  handler: async (session, args) =>
    inspectInstanceHandlerAsync(session, {
      ...toInstanceQuery(args),
      selection: args.selection,
      depth: args.depth,
      properties: args.properties,
      attributes: args.attributes,
      children: args.children,
      descendants: args.descendants,
    }),
});
