import { describe, it, expect, vi } from 'vitest';
import yargs from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  buildYargsCommand,
  renderResult,
} from '../../../cli/adapters/cli-command-adapter.js';
import {
  formatSampleText,
  parseNameList,
  ROLLUP_NOTE,
  sampleCommand,
  sampleInstancesHandlerAsync,
  SampleTextState,
  sortRows,
  watchSampleAsync,
  type SampleValueRow,
} from './sample.js';

// eslint-disable-next-line no-control-regex
const stripAnsi = (text: string) => text.replace(/\u001b\[[0-9;]*m/g, '');

function row(
  frame: number,
  property: string,
  value: SampleValueRow['value'],
  path = 'Workspace.Door'
): SampleValueRow {
  return { kind: 'value', t: frame * 0.016, frame, path, property, value };
}

async function parseSampleArgs(args: string[]): Promise<Record<string, any>> {
  let parsed: Record<string, any> = {};
  await yargs(['sample', ...args])
    .command({
      ...buildYargsCommand(sampleCommand),
      handler: (argv: any) => {
        parsed = argv;
      },
    })
    .parseAsync();
  return parsed;
}

function ref(path: string, className = 'Part') {
  return { path, segments: path.split('.'), className };
}

const refs = Object.fromEntries(
  [
    ref('Workspace.Door'),
    ref('Workspace.Door1'),
    ref('Workspace.Door2'),
    ref('Workspace.Foo', 'Folder'),
    ref('Workspace.Bar', 'Folder'),
  ].map((entry) => [entry.path, entry])
);

function createSession(result: unknown) {
  return { sampleInstancesAsync: vi.fn().mockResolvedValue(result) } as any;
}

const pluginResult = {
  instances: [
    {
      path: 'StarterGui.Stage.Pill',
      segments: ['StarterGui', 'Stage', 'Pill'],
      className: 'Frame',
    },
  ],
  scope: 'query',
  watched: 1,
  omitted: 0,
  rows: [
    {
      kind: 'value',
      t: 0,
      frame: 0,
      path: 'StarterGui.Stage.Pill',
      property: 'Size.X.Scale',
      value: 0.5,
    },
    {
      kind: 'value',
      t: 0.016,
      frame: 1,
      path: 'StarterGui.Stage.Pill',
      property: '@Label',
      value: 'a, "b"',
    },
  ],
  refs: {
    'StarterGui.Stage.Pill': {
      path: 'StarterGui.Stage.Pill',
      segments: ['StarterGui', 'Stage', 'Pill'],
      className: 'Frame',
    },
  },
  recorded: 2,
  frameCount: 2,
  elapsed: 0.016,
  truncated: false,
  clock: 'renderStep',
};

describe('sampleInstancesHandlerAsync', () => {
  it('passes the selection and recording through and summarizes', async () => {
    const session = createSession(pluginResult);

    const result = await sampleInstancesHandlerAsync(session, {
      query: 'Pill',
      root: 'StarterGui.Stage',
      properties: ['Size'],
      duration: 0.8,
      trigger: 'go()',
    });

    expect(session.sampleInstancesAsync).toHaveBeenCalledWith({
      query: 'Pill',
      root: 'StarterGui.Stage',
      properties: ['Size'],
      duration: 0.8,
      trigger: 'go()',
    });
    expect(result.summary).toBe(
      'Sampled 1 instance over 2 frames (0.016s): 1 change'
    );
  });

  it('counts a selector as something to match', async () => {
    const session = createSession(pluginResult);

    await sampleInstancesHandlerAsync(session, {
      selector: 'Frame',
      properties: ['Size'],
      duration: 1,
    });

    expect(session.sampleInstancesAsync).toHaveBeenCalledWith({
      selector: 'Frame',
      properties: ['Size'],
      duration: 1,
    });
  });

  it('records whatever changes without names', async () => {
    const session = createSession(pluginResult);

    await sampleInstancesHandlerAsync(session, { duration: 1 });

    expect(session.sampleInstancesAsync).toHaveBeenCalledWith({ duration: 1 });
  });
});

describe('parseNameList', () => {
  it('splits comma lists and repeats into one list', () => {
    expect(parseNameList(['Size, Position', 'Scale', ''])).toEqual([
      'Size',
      'Position',
      'Scale',
    ]);
  });

  it('takes a single value', () => {
    expect(parseNameList('Size,Position')).toEqual(['Size', 'Position']);
  });
});

describe('sample arguments', () => {
  it('leaves the query after --properties to the positional', async () => {
    const argv = await parseSampleArgs([
      '--properties',
      'Size',
      'Pill',
      'Flag',
      '--duration',
      '1s',
    ]);

    expect(argv.query).toEqual(['Pill', 'Flag']);
    expect(parseNameList(argv.properties)).toEqual(['Size']);
  });

  it('collects repeated --properties and --attributes', async () => {
    const argv = await parseSampleArgs([
      'Pill',
      '--properties',
      'Size,Position',
      '--properties',
      'Scale',
      '--attributes',
      'Progress',
      '--duration',
      '1s',
    ]);

    expect(parseNameList(argv.properties)).toEqual([
      'Size',
      'Position',
      'Scale',
    ]);
    expect(parseNameList(argv.attributes)).toEqual(['Progress']);
  });
});

describe('sample --format csv', () => {
  it('writes a header and quotes fields that need it', async () => {
    const result = await sampleInstancesHandlerAsync(
      createSession(pluginResult),
      { query: 'Pill', properties: ['Size'], duration: 1 }
    );

    expect(renderResult(sampleCommand, result, 'csv')).toBe(
      [
        'kind,t,frame,path,property,value,count,instances,example',
        'value,0,0,StarterGui.Stage.Pill,Size.X.Scale,0.5,,,',
        'value,0.016,1,StarterGui.Stage.Pill,@Label,"a, ""b""",,,',
        '',
      ].join('\n')
    );
  });
});

describe('SampleTextState', () => {
  it('puts components back together, from before the first change to the last', () => {
    const [door] = new SampleTextState([]).collect([
      row(0, 'Color.R', 163),
      row(0, 'Color.G', 162),
      row(0, 'Color.B', 165),
      row(1, 'Color.R', 200),
      row(1, 'Color.G', 162),
      row(1, 'Color.B', 165),
      row(2, 'Color.R', 255),
      row(2, 'Color.G', 0),
      row(2, 'Color.B', 0),
      row(2, 'Transparency', 1),
    ]);

    expect(door.spans.map((span) => [span.name, span.steps])).toEqual([
      ['Color', 2],
      ['Transparency', 1],
    ]);
    expect([...door.spans[0].from.values()]).toEqual([163, 162, 165]);
    expect([...door.spans[0].to.values()]).toEqual([255, 0, 0]);
    expect(door.spans[1].from.get('Transparency')).toBeUndefined();
  });
});

describe('formatSampleText', () => {
  it('prints a line per changed value, prefixed by path', async () => {
    const result = await sampleInstancesHandlerAsync(
      createSession({
        ...pluginResult,
        refs,
        rows: [
          row(0, 'CFrame.Position.Y', 4),
          row(0, 'Name', 'Door'),
          row(1, 'CFrame.Position.Y', 4.500001),
          row(1, 'Name', 'Door'),
        ],
      }),
      { duration: 1 }
    );

    expect(stripAnsi(formatSampleText(result)).split('\n')).toEqual([
      'Workspace/',
      '  Door (Part)',
      '    CFrame.Position  4 → 4.5  0.02s',
    ]);
  });

  it('prints a line per property, a CFrame as position and orientation', async () => {
    const rows: SampleValueRow[] = [];
    for (const [frame, values] of [
      [0, [163, 162, 165, 0, 4, 0, 0, 0, 0]],
      [1, [255, 0, 0, 0, 4, 0, 0, 90, 0]],
    ] as const) {
      [
        'Color.R',
        'Color.G',
        'Color.B',
        'CFrame.Position.X',
        'CFrame.Position.Y',
        'CFrame.Position.Z',
        'CFrame.Orientation.X',
        'CFrame.Orientation.Y',
        'CFrame.Orientation.Z',
      ].forEach((property, index) =>
        rows.push(row(frame, property, values[index]))
      );
    }
    rows.push(row(1, 'BrickColor', 'Really red'));

    const result = await sampleInstancesHandlerAsync(
      createSession({ ...pluginResult, refs, rows }),
      { duration: 1 }
    );

    expect(stripAnsi(formatSampleText(result)).split('\n')).toEqual([
      'Workspace/',
      '  Door (Part)',
      '    BrickColor          → Really red  0.02s',
      '    CFrame.Orientation  0, 0, 0 → 0, 90, 0  0.02s',
      '    Color               163, 162, 165 → 255, 0, 0  0.02s',
    ]);
    expect(result.summary).toBe(
      'Sampled 1 instance over 2 frames (0.016s): 3 changes'
    );
  });

  it('keeps a component asked for with --properties', async () => {
    const result = await sampleInstancesHandlerAsync(
      createSession({
        ...pluginResult,
        refs,
        rows: [row(0, 'Size.X.Scale', 0.5), row(1, 'Size.X.Scale', 1)],
      }),
      { query: 'Door', properties: ['Size.X.Scale'], duration: 1 }
    );

    expect(stripAnsi(formatSampleText(result)).split('\n')[2]).toBe(
      '    Size.X.Scale  0.5 → 1  0.02s'
    );
  });

  it('sums up each value over the recording, in path order', async () => {
    const rows: SampleValueRow[] = [];
    for (const door of ['Door2', 'Door1']) {
      rows.push(row(0, 'Transparency', 0, `Workspace.${door}`));
    }
    for (let frame = 1; frame <= 3; frame++) {
      for (const door of frame === 2
        ? ['Door1', 'Door2']
        : ['Door2', 'Door1']) {
        rows.push(row(frame, 'Transparency', frame / 6, `Workspace.${door}`));
      }
    }
    rows.push(row(2, 'Anchored', true, 'Workspace.Door2'));

    const result = await sampleInstancesHandlerAsync(
      createSession({ ...pluginResult, refs, rows }),
      { duration: 1 }
    );

    expect(stripAnsi(formatSampleText(result)).split('\n')).toEqual([
      'Workspace/',
      '  Door1 (Part)',
      '    Transparency  0 → 0.5  0.02s–0.05s, 3 steps',
      '  Door2 (Part)',
      '    Anchored      → true  0.03s',
      '    Transparency  0 → 0.5  0.02s–0.05s, 3 steps',
    ]);
  });
});

describe('sortRows', () => {
  it('orders rows within a frame by path, then property', () => {
    const sorted = sortRows([
      row(1, 'Size', 2, 'Workspace.B'),
      row(1, 'Color', 2, 'Workspace.B'),
      { kind: 'removed', t: 0.016, frame: 1, path: 'Workspace.A' },
      row(0, 'Size', 1, 'Workspace.B'),
    ]);

    expect(
      sorted.map(
        (r) => `${r.frame} ${r.path} ${'property' in r ? r.property : r.kind}`
      )
    ).toEqual([
      '0 Workspace.B Size',
      '1 Workspace.A removed',
      '1 Workspace.B Color',
      '1 Workspace.B Size',
    ]);
  });
});

describe('watchSampleAsync', () => {
  function createWatchSession(replies: Array<Partial<Record<string, any>>>) {
    const calls: any[] = [];
    const session = {
      sampleInstancesAsync: vi.fn(async (options: any) => {
        calls.push(options);
        const reply = replies.shift() ?? {};
        return { ...pluginResult, refs, rows: [], ...reply };
      }),
    } as any;
    return { session, calls };
  }

  it('streams change lines until the recording ends', async () => {
    const { session, calls } = createWatchSession([
      {},
      { rows: [row(0, '@Open', false), row(3, '@Open', true)] },
      { rows: [row(5, '@Open', false)], ended: true },
    ]);
    const output: string[] = [];

    await watchSampleAsync(
      session,
      { query: 'Door' },
      {
        format: 'text',
        write: (text) => output.push(stripAnsi(text)),
        signal: new AbortController().signal,
      }
    );

    expect(calls).toHaveLength(3);
    expect(calls[0].watch.id).toBe(calls[2].watch.id);
    expect(calls[0].watch.stop).toBeUndefined();
    expect(output.join('')).toBe(
      [
        '0.05s',
        '  Workspace/',
        '    Door (Part)',
        '      @Open  false → true',
        '0.08s',
        '  Workspace/',
        '    Door (Part)',
        '      @Open  true → false',
        '',
      ].join('\n')
    );
  });

  it('stops the watch in Studio once aborted', async () => {
    const controller = new AbortController();
    const { session, calls } = createWatchSession([{}]);
    session.sampleInstancesAsync.mockImplementationOnce(
      async (options: any) => {
        calls.push(options);
        controller.abort();
        return { ...pluginResult, rows: [] };
      }
    );
    const output: string[] = [];

    await watchSampleAsync(
      session,
      {},
      {
        format: 'csv',
        write: (text) => output.push(text),
        signal: controller.signal,
      }
    );

    expect(calls.map((call) => call.watch.stop)).toEqual([undefined, true]);
    expect(output.join('')).toBe(
      'kind,t,frame,path,property,value,count,instances,example\n'
    );
  });

  it('prints instances added and removed, and rollups with a note once', async () => {
    const rollup = {
      kind: 'rollup',
      t: 0.5,
      frame: 30,
      path: 'Workspace.Map.Cars',
      property: 'CFrame',
      count: 1920,
      instances: 48,
      example: 'Workspace.Map.Cars.Car7',
      value: '1, 2, 3',
    };
    const { session } = createWatchSession([
      {},
      {
        rows: [
          { kind: 'added', t: 0.1, frame: 6, path: 'Workspace.Foo' },
          { kind: 'removed', t: 0.2, frame: 12, path: 'Workspace.Bar' },
        ],
      },
      { rows: [rollup] },
      { rows: [rollup], ended: true },
    ]);
    const output: string[] = [];
    const hint = vi.spyOn(OutputHelper, 'hint').mockImplementation(() => {});

    await watchSampleAsync(
      session,
      {},
      {
        format: 'text',
        write: (text) => output.push(stripAnsi(text)),
        signal: new AbortController().signal,
      }
    );

    expect(output.join('')).toBe(
      [
        '0.20s',
        '  Workspace/',
        '    - Bar (Folder)',
        '    + Foo (Folder)',
        '',
      ].join('\n') +
        '0.50s\n  Workspace.Map.Cars.** (48 instances)  CFrame  ×1,920 changes  e.g. Workspace.Map.Cars.Car7 = 1, 2, 3\n'.repeat(
          2
        )
    );
    expect(
      hint.mock.calls.filter(([message]) => message === ROLLUP_NOTE)
    ).toHaveLength(1);
    hint.mockRestore();
  });
});

describe('formatSampleText', () => {
  it('lists the instances in a tree when nothing changed', async () => {
    const result = await sampleInstancesHandlerAsync(
      createSession({ ...pluginResult, rows: [] }),
      { duration: 1 }
    );

    expect(stripAnsi(formatSampleText(result))).toBe(
      'StarterGui/Stage/\n  Pill (Frame)'
    );
  });

  it('summarizes what the place scope recorded, with a cap notice', async () => {
    const result = await sampleInstancesHandlerAsync(
      createSession({
        ...pluginResult,
        scope: 'place',
        watched: 11634,
        omitted: 5,
        refs,
        rows: [
          row(0, 'Transparency', 0),
          row(1, 'Transparency', 1),
          { kind: 'added', t: 0.016, frame: 1, path: 'Workspace.Foo' },
        ],
      }),
      { duration: 1 }
    );

    expect(result.summary).toBe(
      'Sampled 11,634 instances in the place over 2 frames (0.016s): 1 change, 1 added. Left out 5 more rows past the cap; narrow with a query or a shorter --duration'
    );
    expect(stripAnsi(formatSampleText(result)).split('\n')).toEqual([
      'Workspace/',
      '  Door (Part)',
      '    Transparency  0 → 1  0.02s',
      '  + Foo (Folder, 0.02s)',
    ]);
  });
});

describe('sample --format csv rollups', () => {
  it('fills the rollup columns and leaves the rest empty', async () => {
    const result = await sampleInstancesHandlerAsync(
      createSession({
        ...pluginResult,
        rows: [
          {
            kind: 'rollup',
            t: 0.5,
            frame: 30,
            path: 'Workspace.Map',
            property: 'CFrame',
            count: 10,
            instances: 2,
          },
        ],
      }),
      { duration: 1 }
    );

    expect(renderResult(sampleCommand, result, 'csv').split('\n')[1]).toBe(
      'rollup,0.5,30,Workspace.Map,CFrame,,10,2,'
    );
  });
});

describe('sample defaults', () => {
  it('records the place for 2s with no arguments', async () => {
    const session = createSession(pluginResult);

    await (sampleCommand as any).handler(session, {});

    expect(session.sampleInstancesAsync).toHaveBeenCalledWith(
      expect.objectContaining({ duration: 2, selection: undefined })
    );
  });

  it('opts in to the selection with --selection', async () => {
    const argv = await parseSampleArgs(['--selection']);

    expect(argv.selection).toBe(true);
  });
});

describe('sample --watch', () => {
  it('needs no query, names or duration', async () => {
    const argv = await parseSampleArgs(['--watch']);

    expect(argv.watch).toBe(true);
    expect(argv.duration).toBeUndefined();
    expect(argv.interval).toBeUndefined();
  });
});
