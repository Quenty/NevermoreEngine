import {
  formatCount,
  formatTree,
  type TreeNode,
  type TreeOptions,
} from '@quenty/cli-output-helpers/reporting';
import type {
  InstanceMatchesDetails,
  InstanceRef,
} from '../../server/web-socket-protocol.js';

export interface InstanceTreeOptions<T extends InstanceRef>
  extends TreeOptions {
  children?: (ref: T) => TreeNode[];
  omitSharedClassName?: boolean;
  annotate?: (ref: T) => { marker?: string; annotation?: string };
}

const SERVICE_ORDER = [
  'Workspace',
  'Players',
  'Lighting',
  'MaterialService',
  'ReplicatedFirst',
  'ReplicatedStorage',
  'ServerScriptService',
  'ServerStorage',
  'StarterGui',
  'StarterPack',
  'StarterPlayer',
  'Teams',
  'SoundService',
  'TextChatService',
];

export function sharedClassName(refs: InstanceRef[]): string | undefined {
  const className = refs[0]?.className;
  return refs.every((ref) => ref.className === className)
    ? className
    : undefined;
}

export function formatClassCount(count: number, className: string): string {
  const plural = /[^aeiou]y$/i.test(className)
    ? `${className.slice(0, -1)}ies`
    : /(s|x|ch|sh)$/.test(className)
    ? `${className}es`
    : `${className}s`;
  return formatCount(count, className, plural);
}

interface Branch {
  node: TreeNode & { children: TreeNode[] };
  byName: Map<string, Branch>;
}

function createBranch(parent: Branch, label: string): Branch {
  const branch: Branch = {
    node: { label, children: [] },
    byName: new Map(),
  };
  parent.node.children.push(branch.node);
  parent.byName.set(label, branch);
  return branch;
}

function compareName(a: string, b: string): number {
  const lowerA = a.toLowerCase();
  const lowerB = b.toLowerCase();
  if (lowerA !== lowerB) return lowerA < lowerB ? -1 : 1;
  return a < b ? -1 : a > b ? 1 : 0;
}

function serviceRank(name: string): number {
  const rank = SERVICE_ORDER.indexOf(name);
  return rank === -1 ? SERVICE_ORDER.length : rank;
}

export function compareSegments(a: string[], b: string[]): number {
  if (a.length > 0 && b.length > 0) {
    const rank = serviceRank(a[0]) - serviceRank(b[0]);
    if (rank !== 0) return rank;
  }
  for (let i = 0; i < Math.min(a.length, b.length); i++) {
    const order = compareName(a[i], b[i]);
    if (order !== 0) return order;
  }
  return a.length - b.length;
}

export function buildInstanceTree<T extends InstanceRef>(
  refs: T[],
  options?: InstanceTreeOptions<T>
): TreeNode[] {
  const root: Branch = { node: { label: '', children: [] }, byName: new Map() };
  const omitClassName =
    options?.omitSharedClassName && sharedClassName(refs) !== undefined;
  const sorted = [...refs].sort((a, b) =>
    compareSegments(a.segments, b.segments)
  );

  for (const ref of sorted) {
    let parent = root;
    ref.segments.forEach((name, index) => {
      const existing = parent.byName.get(name);
      if (index < ref.segments.length - 1) {
        parent = existing ?? createBranch(parent, name);
        return;
      }

      const branch =
        existing && !existing.node.isMatch
          ? existing
          : createBranch(parent, name);
      branch.node.isMatch = true;
      const { marker, annotation } = options?.annotate?.(ref) ?? {};
      if (marker) {
        branch.node.label = `${marker} ${name}`;
      }
      const className =
        omitClassName || ref.className === name ? undefined : ref.className;
      branch.node.annotation =
        [className, annotation].filter((part) => part).join(', ') || undefined;
      branch.node.children.unshift(...(options?.children?.(ref) ?? []));
      parent = branch;
    });
  }

  return root.node.children;
}

export function formatInstanceTree<T extends InstanceRef>(
  refs: T[],
  options?: InstanceTreeOptions<T>
): string {
  return formatTree(buildInstanceTree(refs, options), options);
}

export function isInstanceMatchesDetails(
  details: unknown
): details is InstanceMatchesDetails {
  const candidate = details as Partial<InstanceMatchesDetails> | undefined;
  return (
    typeof candidate?.total === 'number' && Array.isArray(candidate.matches)
  );
}

export function formatInstanceMatches(
  message: string,
  { matches, total }: InstanceMatchesDetails
): string {
  return [
    `${message}:`,
    formatInstanceTree(matches),
    ...(total > matches.length
      ? [`and ${formatCount(total - matches.length, 'more', 'more')}`]
      : []),
    'Narrow it to one, e.g. with its parent (Parent.Name) or is:Class',
  ].join('\n');
}
