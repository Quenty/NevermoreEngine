import { describe, it, expect, vi } from 'vitest';
import yargs from 'yargs';
import { buildYargsCommand } from '../../../cli/adapters/cli-command-adapter.js';
import {
  formatSampleCsv,
  parseNameList,
  sampleCommand,
  sampleInstancesHandlerAsync,
} from './sample.js';

/** Parses `explorer sample` arguments the way the CLI does. */
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

function createSession(result: unknown) {
  return { sampleInstancesAsync: vi.fn().mockResolvedValue(result) } as any;
}

const pluginResult = {
  instances: ['StarterGui.Stage.Pill'],
  rows: [
    {
      t: 0,
      frame: 0,
      path: 'StarterGui.Stage.Pill',
      property: 'Size.X.Scale',
      value: 0.5,
    },
    {
      t: 0.016,
      frame: 1,
      path: 'StarterGui.Stage.Pill',
      property: '@Label',
      value: 'a, "b"',
    },
  ],
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
      names: ['Pill'],
      root: 'StarterGui.Stage',
      properties: ['Size'],
      duration: 0.8,
      trigger: 'go()',
    });

    expect(session.sampleInstancesAsync).toHaveBeenCalledWith({
      names: ['Pill'],
      root: 'StarterGui.Stage',
      properties: ['Size'],
      duration: 0.8,
      trigger: 'go()',
    });
    expect(result.summary).toBe(
      'Sampled 1 instance(s) over 2 frames (0.016s): 2 values'
    );
  });

  it('counts the legacy name field as something to match', async () => {
    const session = createSession(pluginResult);

    await sampleInstancesHandlerAsync(session, {
      name: 'Pill',
      properties: ['Size'],
      duration: 1,
    });

    expect(session.sampleInstancesAsync).toHaveBeenCalledWith({
      names: ['Pill'],
      properties: ['Size'],
      duration: 1,
    });
  });

  it('needs something to match', async () => {
    await expect(
      sampleInstancesHandlerAsync(createSession(pluginResult), {
        properties: ['Size'],
        duration: 1,
      })
    ).rejects.toThrow('Give a name, --class or --tag to sample');
  });

  it('needs something to record', async () => {
    await expect(
      sampleInstancesHandlerAsync(createSession(pluginResult), {
        names: ['Pill'],
        duration: 1,
      })
    ).rejects.toThrow('Give --properties or --attributes');
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
  it('leaves names after --properties to the positional', async () => {
    const argv = await parseSampleArgs([
      '--properties',
      'Size',
      'Pill',
      'Flag',
      '--duration',
      '1s',
    ]);

    expect(argv.names).toEqual(['Pill', 'Flag']);
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

describe('formatSampleCsv', () => {
  it('writes a header and quotes fields that need it', async () => {
    const result = await sampleInstancesHandlerAsync(
      createSession(pluginResult),
      { names: ['Pill'], properties: ['Size'], duration: 1 }
    );

    expect(formatSampleCsv(result)).toBe(
      [
        't,frame,path,property,value',
        '0,0,StarterGui.Stage.Pill,Size.X.Scale,0.5',
        '0.016,1,StarterGui.Stage.Pill,@Label,"a, ""b"""',
        '',
      ].join('\n')
    );
  });
});
