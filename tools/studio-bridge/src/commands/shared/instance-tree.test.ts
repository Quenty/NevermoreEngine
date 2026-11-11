import { describe, it, expect } from 'vitest';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  formatClassCount,
  formatInstanceMatches,
  formatInstanceTree as formatColoredInstanceTree,
  type InstanceTreeOptions,
} from './instance-tree.js';
import type { InstanceRef } from '../../server/web-socket-protocol.js';

function ref(segments: string[], className: string): InstanceRef {
  return { path: segments.join('.'), segments, className };
}

function formatInstanceTree<T extends InstanceRef>(
  refs: T[],
  options?: InstanceTreeOptions<T>
): string {
  return OutputHelper.stripAnsi(formatColoredInstanceTree(refs, options));
}

describe('formatInstanceTree', () => {
  it('nests instances under their ancestors, collapsing lone ancestors', () => {
    const text = formatInstanceTree([
      ref(['Workspace', 'Map', 'Doors', 'Gate'], 'Model'),
      ref(['Workspace', 'Map', 'Doors', 'Door'], 'Part'),
      ref(['Workspace', 'Terrain'], 'Terrain'),
    ]);

    expect(text).toBe(
      [
        'Workspace/',
        '  Map/Doors/',
        '    Door (Part)',
        '    Gate (Model)',
        '  Terrain',
      ].join('\n')
    );
  });

  it('keeps a name with dots as one node', () => {
    const text = formatInstanceTree([
      ref(['ReplicatedStorage', 'jsdotlua_shared@17.2.1', 'A'], 'Folder'),
      ref(['ReplicatedStorage', 'jsdotlua_shared@17.2.1', 'B'], 'Folder'),
    ]);

    expect(text).toBe(
      [
        'ReplicatedStorage/jsdotlua_shared@17.2.1/',
        '  A (Folder)',
        '  B (Folder)',
      ].join('\n')
    );
  });

  it('puts services in Explorer order and siblings alphabetically, whatever order they arrive in', () => {
    const refs = [
      ref(['Workspace', 'b'], 'Part'),
      ref(['Workspace', 'A'], 'Part'),
      ref(['Chat'], 'Chat'),
      ref(['Lighting'], 'Lighting'),
      ref(['Atmosphere'], 'Folder'),
    ];

    const text = formatInstanceTree(refs);

    expect(formatInstanceTree([...refs].reverse())).toBe(text);
    expect(text).toBe(
      [
        'Workspace/',
        '  A (Part)',
        '  b (Part)',
        'Lighting',
        'Atmosphere (Folder)',
        'Chat',
      ].join('\n')
    );
  });

  it('shows a matched ancestor as a result, with its matches under it', () => {
    const text = formatInstanceTree([
      ref(['Workspace', 'Model', 'Part'], 'Part'),
      ref(['Workspace', 'Model'], 'Model'),
    ]);

    expect(text).toBe(['Workspace/', '  Model', '    Part'].join('\n'));
  });

  it('gives instances with the same name and parent a node each', () => {
    const text = formatInstanceTree([
      ref(['Workspace', 'Part'], 'Part'),
      ref(['Workspace', 'Part'], 'Part'),
    ]);

    expect(text).toBe(['Workspace/', '  Part', '  Part'].join('\n'));
  });

  it('leaves out a class every instance shares, when asked', () => {
    const refs = [
      ref(['Workspace', 'A'], 'Part'),
      ref(['Workspace', 'B'], 'Part'),
    ];

    expect(formatInstanceTree(refs, { omitSharedClassName: true })).toBe(
      ['Workspace/', '  A', '  B'].join('\n')
    );
    expect(
      formatInstanceTree([...refs, ref(['Workspace', 'C'], 'Model')], {
        omitSharedClassName: true,
      })
    ).toBe(
      ['Workspace/', '  A (Part)', '  B (Part)', '  C (Model)'].join('\n')
    );
  });

  it('puts the given children under a result', () => {
    const text = formatInstanceTree(
      [{ ...ref(['ServerScriptService', 'Main'], 'Script'), lines: ['1: a'] }],
      { children: (script) => script.lines.map((label) => ({ label })) }
    );

    expect(text).toBe(
      ['ServerScriptService/', '  Main (Script)', '    1: a'].join('\n')
    );
  });

  it('marks an instance and adds to its detail when annotated', () => {
    const text = formatInstanceTree([ref(['Workspace', 'Door'], 'Part')], {
      annotate: () => ({ marker: '+', annotation: '0.07s' }),
    });

    expect(text).toBe(['Workspace/', '  + Door (Part, 0.07s)'].join('\n'));
  });
});

describe('formatClassCount', () => {
  it('pluralizes a class name in simple English', () => {
    expect(formatClassCount(1, 'Part')).toBe('1 Part');
    expect(formatClassCount(601, 'ModuleScript')).toBe('601 ModuleScripts');
    expect(formatClassCount(2, 'Accessory')).toBe('2 Accessories');
    expect(formatClassCount(2, 'Key')).toBe('2 Keys');
    expect(formatClassCount(2, 'Sky')).toBe('2 Skies');
    expect(formatClassCount(1_532, 'Attachment')).toBe('1,532 Attachments');
  });
});

describe('formatInstanceMatches', () => {
  it('lists the matches under the message, counts the rest, and says to narrow it', () => {
    const text = OutputHelper.stripAnsi(
      formatInstanceMatches("25 instances match 'Door', where one is needed", {
        matches: [
          ref(['Workspace', 'A', 'Door'], 'Part'),
          ref(['Workspace', 'B', 'Door'], 'Part'),
        ],
        total: 25,
      })
    );

    expect(text.split(String.fromCharCode(10))).toEqual([
      "25 instances match 'Door', where one is needed:",
      'Workspace/',
      '  A/',
      '    Door (Part)',
      '  B/',
      '    Door (Part)',
      'and 23 more',
      'Narrow it to one, e.g. with its parent (Parent.Name) or is:Class',
    ]);
  });
});
