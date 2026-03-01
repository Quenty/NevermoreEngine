/**
 * Argument definition DSL and schema converters.
 *
 * `arg.positional()`, `arg.option()`, and `arg.flag()` produce `ArgDefinition`
 * objects that carry enough metadata to generate both yargs options and
 * JSON Schema properties for MCP tools.
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ArgKind = 'positional' | 'option' | 'flag';
export type ArgType = 'string' | 'number' | 'boolean';

export interface ArgDefinition {
  kind: ArgKind;
  type: ArgType;
  description: string;
  required?: boolean;
  default?: unknown;
  alias?: string;
  choices?: readonly string[];
  array?: boolean;
}

// ---------------------------------------------------------------------------
// DSL
// ---------------------------------------------------------------------------

export const arg = {
  /**
   * Define a positional argument. Required by default.
   *
   * ```ts
   * args: { code: arg.positional({ description: 'Luau source code' }) }
   * ```
   */
  positional(config: {
    description: string;
    type?: 'string' | 'number';
    required?: boolean;
    choices?: readonly string[];
  }): ArgDefinition {
    return {
      kind: 'positional',
      type: config.type ?? 'string',
      description: config.description,
      required: config.required ?? true,
      choices: config.choices,
    };
  },

  /**
   * Define a named option (`--name <value>`).
   *
   * ```ts
   * args: { count: arg.option({ description: 'Max entries', type: 'number' }) }
   * ```
   */
  option(config: {
    description: string;
    type?: 'string' | 'number';
    alias?: string;
    required?: boolean;
    default?: string | number;
    choices?: readonly string[];
    array?: boolean;
  }): ArgDefinition {
    return {
      kind: 'option',
      type: config.type ?? 'string',
      description: config.description,
      alias: config.alias,
      required: config.required,
      default: config.default,
      choices: config.choices,
      array: config.array,
    };
  },

  /**
   * Define a boolean flag (`--verbose`, `--json`).
   *
   * ```ts
   * args: { children: arg.flag({ description: 'Include children' }) }
   * ```
   */
  flag(config: {
    description: string;
    alias?: string;
    default?: boolean;
  }): ArgDefinition {
    return {
      kind: 'flag',
      type: 'boolean',
      description: config.description,
      alias: config.alias,
      default: config.default ?? false,
    };
  },
};

// ---------------------------------------------------------------------------
// Yargs conversion
// ---------------------------------------------------------------------------

export interface YargsPositional {
  name: string;
  options: {
    describe: string;
    type: 'string' | 'number';
    demandOption?: boolean;
    choices?: readonly string[];
  };
}

export interface YargsArgConfig {
  positionals: YargsPositional[];
  options: Record<string, Record<string, unknown>>;
}

/**
 * Convert an args record into yargs-compatible positional and option configs.
 */
export function toYargsOptions(args: Record<string, ArgDefinition>): YargsArgConfig {
  const positionals: YargsPositional[] = [];
  const options: Record<string, Record<string, unknown>> = {};

  for (const [name, def] of Object.entries(args)) {
    if (def.kind === 'positional') {
      positionals.push({
        name,
        options: {
          describe: def.description,
          type: def.type as 'string' | 'number',
          demandOption: def.required,
          ...(def.choices ? { choices: def.choices } : {}),
        },
      });
    } else {
      const opt: Record<string, unknown> = {
        describe: def.description,
        type: def.type,
      };
      if (def.alias) opt.alias = def.alias;
      if (def.default !== undefined) opt.default = def.default;
      if (def.choices) opt.choices = def.choices;
      if (def.array) opt.array = def.array;
      options[name] = opt;
    }
  }

  return { positionals, options };
}

// ---------------------------------------------------------------------------
// JSON Schema conversion (for MCP tools)
// ---------------------------------------------------------------------------

export interface JsonSchemaOutput {
  type: 'object';
  properties: Record<string, Record<string, unknown>>;
  required?: string[];
  additionalProperties: false;
}

/**
 * Convert an args record into a JSON Schema object suitable for MCP tool
 * `inputSchema`. Positional args that are required become `required` in
 * the schema. Options with `required: true` are also included.
 */
export function toJsonSchema(args: Record<string, ArgDefinition>): JsonSchemaOutput {
  const properties: Record<string, Record<string, unknown>> = {};
  const required: string[] = [];

  for (const [name, def] of Object.entries(args)) {
    const prop: Record<string, unknown> = {
      description: def.description,
    };

    if (def.array) {
      prop.type = 'array';
      prop.items = { type: def.type };
    } else {
      prop.type = def.type;
    }

    if (def.choices) {
      prop.enum = [...def.choices];
    }

    if (def.default !== undefined) {
      prop.default = def.default;
    }

    properties[name] = prop;

    if (def.required) {
      required.push(name);
    }
  }

  const schema: JsonSchemaOutput = {
    type: 'object',
    properties,
    additionalProperties: false,
  };

  if (required.length > 0) {
    schema.required = required;
  }

  return schema;
}
