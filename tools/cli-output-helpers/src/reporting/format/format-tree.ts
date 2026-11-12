import { OutputHelper } from '../../outputHelper.js';

/** A line of a rendered tree; matches stand out from the context around them. */
export interface TreeNode {
  label: string;
  annotation?: string;
  children?: TreeNode[];
  isMatch?: boolean;
}

/** How a tree is laid out. */
export interface TreeOptions {
  linePrefix?: string;
  maxLineWidth?: number;
}

export const DEFAULT_MAX_LINE_WIDTH = 100;

const SEPARATOR = '/';

function isContext(node: TreeNode): boolean {
  return !node.isMatch && (node.children?.length ?? 0) > 0;
}

function collapseChain(node: TreeNode): TreeNode[] {
  const chain = [node];
  let current = node;
  while (
    !current.annotation &&
    current.children?.length === 1 &&
    isContext(current.children[0])
  ) {
    current = current.children[0];
    chain.push(current);
  }
  return chain;
}

function joinChain(labels: string[], room: number): string {
  let text = labels.join(SEPARATOR);
  for (let keep = labels.length - 2; keep >= 1 && text.length > room; keep--) {
    text = [labels[0], '…', ...labels.slice(-keep)].join(SEPARATOR);
  }
  return text;
}

function renderNode(
  node: TreeNode,
  indent: string,
  maxLineWidth: number,
  lines: string[]
): void {
  const chain = isContext(node) ? collapseChain(node) : [node];
  const end = chain[chain.length - 1];
  const annotation = end.annotation ? ` (${end.annotation})` : '';

  const label = isContext(node)
    ? OutputHelper.formatDim(
        joinChain(
          chain.map((link) => link.label),
          maxLineWidth - indent.length - annotation.length - SEPARATOR.length
        ) + SEPARATOR
      )
    : node.label;
  lines.push(
    `${indent}${label}${
      annotation && ` ${OutputHelper.formatDim(annotation.trim())}`
    }`
  );

  for (const child of end.children ?? []) {
    renderNode(child, `${indent}  `, maxLineWidth, lines);
  }
}

export function formatTree(nodes: TreeNode[], options?: TreeOptions): string {
  const lines: string[] = [];
  for (const node of nodes) {
    renderNode(
      node,
      options?.linePrefix ?? '',
      options?.maxLineWidth ?? DEFAULT_MAX_LINE_WIDTH,
      lines
    );
  }
  return lines.join('\n');
}
