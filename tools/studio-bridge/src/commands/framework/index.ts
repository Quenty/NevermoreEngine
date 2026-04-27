/**
 * Declarative command framework. `defineCommand()` creates a single
 * definition that drives the CLI adapter.
 */

export {
  COMMAND_BRAND,
  defineCommand,
  isCommandDefinition,
  type CommandSafety,
  type CommandScope,
  type CommandCategory,
  type CommandInput,
  type CommandDefinition,
  type SessionCommandInput,
  type ConnectionCommandInput,
  type StandaloneCommandInput,
  type CliConfig,
} from './define-command.js';

export {
  arg,
  toYargsOptions,
  toJsonSchema,
  type ArgKind,
  type ArgType,
  type ArgDefinition,
  type YargsPositional,
  type YargsArgConfig,
  type JsonSchemaOutput,
} from './arg-builder.js';

export { CommandRegistry, type DiscoverOptions } from './command-registry.js';
