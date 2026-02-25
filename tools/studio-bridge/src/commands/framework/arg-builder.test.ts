/**
 * Unit tests for the arg builder DSL and schema converters.
 */

import { describe, it, expect } from 'vitest';
import { arg, toYargsOptions, toJsonSchema } from './arg-builder.js';

// ---------------------------------------------------------------------------
// arg.positional
// ---------------------------------------------------------------------------

describe('arg.positional', () => {
  it('creates a positional arg definition', () => {
    const def = arg.positional({ description: 'Source code' });
    expect(def.kind).toBe('positional');
    expect(def.description).toBe('Source code');
  });

  it('defaults to string type', () => {
    const def = arg.positional({ description: 'test' });
    expect(def.type).toBe('string');
  });

  it('respects explicit number type', () => {
    const def = arg.positional({ description: 'test', type: 'number' });
    expect(def.type).toBe('number');
  });

  it('defaults to required', () => {
    const def = arg.positional({ description: 'test' });
    expect(def.required).toBe(true);
  });

  it('allows optional positionals', () => {
    const def = arg.positional({ description: 'test', required: false });
    expect(def.required).toBe(false);
  });

  it('supports choices', () => {
    const def = arg.positional({
      description: 'Direction',
      choices: ['head', 'tail'] as const,
    });
    expect(def.choices).toEqual(['head', 'tail']);
  });
});

// ---------------------------------------------------------------------------
// arg.option
// ---------------------------------------------------------------------------

describe('arg.option', () => {
  it('creates an option arg definition', () => {
    const def = arg.option({ description: 'Max count' });
    expect(def.kind).toBe('option');
    expect(def.description).toBe('Max count');
  });

  it('defaults to string type', () => {
    const def = arg.option({ description: 'test' });
    expect(def.type).toBe('string');
  });

  it('supports number type', () => {
    const def = arg.option({ description: 'test', type: 'number' });
    expect(def.type).toBe('number');
  });

  it('supports alias', () => {
    const def = arg.option({ description: 'test', alias: 'n' });
    expect(def.alias).toBe('n');
  });

  it('supports default value', () => {
    const def = arg.option({ description: 'test', type: 'number', default: 50 });
    expect(def.default).toBe(50);
  });

  it('supports required flag', () => {
    const def = arg.option({ description: 'test', required: true });
    expect(def.required).toBe(true);
  });

  it('supports choices', () => {
    const def = arg.option({
      description: 'Mode',
      choices: ['text', 'json'] as const,
    });
    expect(def.choices).toEqual(['text', 'json']);
  });

  it('supports array flag', () => {
    const def = arg.option({ description: 'Levels', array: true });
    expect(def.array).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// arg.flag
// ---------------------------------------------------------------------------

describe('arg.flag', () => {
  it('creates a flag arg definition', () => {
    const def = arg.flag({ description: 'Include children' });
    expect(def.kind).toBe('flag');
    expect(def.type).toBe('boolean');
  });

  it('defaults to false', () => {
    const def = arg.flag({ description: 'test' });
    expect(def.default).toBe(false);
  });

  it('allows default true', () => {
    const def = arg.flag({ description: 'test', default: true });
    expect(def.default).toBe(true);
  });

  it('supports alias', () => {
    const def = arg.flag({ description: 'test', alias: 'c' });
    expect(def.alias).toBe('c');
  });
});

// ---------------------------------------------------------------------------
// toYargsOptions
// ---------------------------------------------------------------------------

describe('toYargsOptions', () => {
  it('separates positionals from options', () => {
    const result = toYargsOptions({
      code: arg.positional({ description: 'Source' }),
      count: arg.option({ description: 'Max', type: 'number' }),
      verbose: arg.flag({ description: 'Verbose' }),
    });

    expect(result.positionals).toHaveLength(1);
    expect(result.positionals[0].name).toBe('code');
    expect(Object.keys(result.options)).toEqual(['count', 'verbose']);
  });

  it('converts positional fields', () => {
    const result = toYargsOptions({
      path: arg.positional({
        description: 'DataModel path',
        choices: ['Workspace', 'ServerStorage'] as const,
      }),
    });

    const pos = result.positionals[0];
    expect(pos.options.describe).toBe('DataModel path');
    expect(pos.options.type).toBe('string');
    expect(pos.options.demandOption).toBe(true);
    expect(pos.options.choices).toEqual(['Workspace', 'ServerStorage']);
  });

  it('converts option fields', () => {
    const result = toYargsOptions({
      count: arg.option({
        description: 'Number of entries',
        type: 'number',
        alias: 'n',
        default: 50,
      }),
    });

    const opt = result.options.count;
    expect(opt.describe).toBe('Number of entries');
    expect(opt.type).toBe('number');
    expect(opt.alias).toBe('n');
    expect(opt.default).toBe(50);
  });

  it('converts flag fields', () => {
    const result = toYargsOptions({
      json: arg.flag({ description: 'Output JSON', alias: 'j' }),
    });

    const opt = result.options.json;
    expect(opt.describe).toBe('Output JSON');
    expect(opt.type).toBe('boolean');
    expect(opt.alias).toBe('j');
    expect(opt.default).toBe(false);
  });

  it('omits undefined optional fields from options', () => {
    const result = toYargsOptions({
      name: arg.option({ description: 'Name' }),
    });

    const opt = result.options.name;
    expect(opt).not.toHaveProperty('alias');
    expect(opt).not.toHaveProperty('default');
    expect(opt).not.toHaveProperty('choices');
    expect(opt).not.toHaveProperty('array');
  });

  it('returns empty arrays for no args', () => {
    const result = toYargsOptions({});
    expect(result.positionals).toEqual([]);
    expect(result.options).toEqual({});
  });
});

// ---------------------------------------------------------------------------
// toJsonSchema
// ---------------------------------------------------------------------------

describe('toJsonSchema', () => {
  it('generates a valid object schema', () => {
    const schema = toJsonSchema({
      code: arg.positional({ description: 'Source code' }),
    });

    expect(schema.type).toBe('object');
    expect(schema.additionalProperties).toBe(false);
    expect(schema.properties.code).toBeDefined();
  });

  it('includes required positionals in required array', () => {
    const schema = toJsonSchema({
      code: arg.positional({ description: 'Source code' }),
    });

    expect(schema.required).toEqual(['code']);
  });

  it('includes required options in required array', () => {
    const schema = toJsonSchema({
      target: arg.option({ description: 'Target', required: true }),
    });

    expect(schema.required).toEqual(['target']);
  });

  it('omits required array when no args are required', () => {
    const schema = toJsonSchema({
      count: arg.option({ description: 'Count', type: 'number' }),
      verbose: arg.flag({ description: 'Verbose' }),
    });

    expect(schema).not.toHaveProperty('required');
  });

  it('maps string type', () => {
    const schema = toJsonSchema({
      name: arg.option({ description: 'Name' }),
    });

    expect(schema.properties.name.type).toBe('string');
  });

  it('maps number type', () => {
    const schema = toJsonSchema({
      count: arg.option({ description: 'Count', type: 'number' }),
    });

    expect(schema.properties.count.type).toBe('number');
  });

  it('maps boolean type for flags', () => {
    const schema = toJsonSchema({
      verbose: arg.flag({ description: 'Verbose' }),
    });

    expect(schema.properties.verbose.type).toBe('boolean');
  });

  it('maps array options', () => {
    const schema = toJsonSchema({
      levels: arg.option({ description: 'Log levels', array: true }),
    });

    expect(schema.properties.levels.type).toBe('array');
    expect(schema.properties.levels.items).toEqual({ type: 'string' });
  });

  it('maps choices to enum', () => {
    const schema = toJsonSchema({
      direction: arg.option({
        description: 'Direction',
        choices: ['head', 'tail'] as const,
      }),
    });

    expect(schema.properties.direction.enum).toEqual(['head', 'tail']);
  });

  it('includes default values', () => {
    const schema = toJsonSchema({
      count: arg.option({ description: 'Count', type: 'number', default: 50 }),
    });

    expect(schema.properties.count.default).toBe(50);
  });

  it('includes description on all properties', () => {
    const schema = toJsonSchema({
      code: arg.positional({ description: 'Source code' }),
      count: arg.option({ description: 'Max entries', type: 'number' }),
      json: arg.flag({ description: 'JSON output' }),
    });

    expect(schema.properties.code.description).toBe('Source code');
    expect(schema.properties.count.description).toBe('Max entries');
    expect(schema.properties.json.description).toBe('JSON output');
  });

  it('returns empty properties for no args', () => {
    const schema = toJsonSchema({});
    expect(schema.properties).toEqual({});
    expect(schema).not.toHaveProperty('required');
  });
});
