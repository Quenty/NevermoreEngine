import { describe, it, expect, afterEach } from 'vitest';
import chalk from 'chalk';
import { formatTree, type TreeNode } from './format-tree.js';

const originalLevel = chalk.level;

afterEach(() => {
  chalk.level = originalLevel;
});

function plain(nodes: TreeNode[], options?: Parameters<typeof formatTree>[1]) {
  chalk.level = 0;
  return formatTree(nodes, options);
}

function chainOf(labels: string[], leaf: TreeNode): TreeNode {
  return labels.reduceRight<TreeNode>(
    (child, label) => ({ label, children: [child] }),
    leaf
  );
}

describe('formatTree', () => {
  it('indents children by two spaces, with the annotation in parentheses', () => {
    const text = plain([
      {
        label: 'Workspace',
        isMatch: true,
        children: [
          { label: 'Door', annotation: 'Part', isMatch: true },
          { label: 'Camera', isMatch: true },
        ],
      },
    ]);

    expect(text).toBe(['Workspace', '  Door (Part)', '  Camera'].join('\n'));
  });

  it('collapses a chain of single-child context nodes onto one slashed line', () => {
    const text = plain([
      chainOf(['Workspace', 'Map'], {
        label: 'Doors',
        children: [
          { label: 'Door', annotation: 'Part', isMatch: true },
          { label: 'Gate', annotation: 'Model', isMatch: true },
        ],
      }),
    ]);

    expect(text).toBe(
      ['Workspace/Map/Doors/', '  Door (Part)', '  Gate (Model)'].join('\n')
    );
  });

  it('starts a lone result on its own line under its context', () => {
    const text = plain([
      chainOf(['Workspace', 'Map'], { label: 'Door', isMatch: true }),
    ]);

    expect(text).toBe(['Workspace/Map/', '  Door'].join('\n'));
  });

  it('does not collapse a result, which has no slash even with children', () => {
    const text = plain([
      {
        label: 'Workspace',
        children: [
          {
            label: 'Script',
            isMatch: true,
            children: [
              { label: '3: require(x)' },
              { label: 'Child', isMatch: true },
            ],
          },
        ],
      },
    ]);

    expect(text).toBe(
      ['Workspace/', '  Script', '    3: require(x)', '    Child'].join('\n')
    );
  });

  it('shortens a long context chain in the middle, keeping the first label', () => {
    const labels = ['ServerScriptService', 'a'.repeat(30), 'b'.repeat(30)];
    const nodes = [
      chainOf([...labels, 'Packages'], {
        label: 'x'.repeat(120),
        isMatch: true,
      }),
    ];

    expect(plain(nodes)).toBe(
      [`${labels.join('/')}/Packages/`, `  ${'x'.repeat(120)}`].join('\n')
    );
    expect(plain(nodes, { maxLineWidth: 70 }).split('\n')[0]).toBe(
      `ServerScriptService/…/${'b'.repeat(30)}/Packages/`
    );
    expect(
      plain(nodes, { maxLineWidth: 70, linePrefix: '          ' }).split(
        '\n'
      )[0]
    ).toBe('          ServerScriptService/…/Packages/');
  });

  it('prefixes every line with the line prefix', () => {
    expect(
      plain([{ label: 'A', children: [{ label: 'B' }, { label: 'C' }] }], {
        linePrefix: '> ',
      })
    ).toBe(['> A/', '>   B', '>   C'].join('\n'));
  });

  it('renders context and details dim, and results plain', () => {
    chalk.level = 1;
    const text = formatTree([
      {
        label: 'Workspace',
        children: [
          { label: 'A', annotation: 'Part', isMatch: true },
          { label: 'B', isMatch: true },
        ],
      },
    ]);

    const [context, result] = text.split('\n');
    expect(context).toBe(chalk.dim('Workspace/'));
    expect(result).toBe(`  A ${chalk.dim('(Part)')}`);
  });

  it('returns an empty string for no nodes', () => {
    expect(formatTree([])).toBe('');
  });
});
