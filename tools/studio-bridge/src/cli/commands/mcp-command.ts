/**
 * `studio-bridge mcp` -- start an MCP server on stdio.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { mcpHandlerAsync } from '../../commands/mcp.js';

export type McpArgs = StudioBridgeGlobalArgs;

export class McpCommand<T> implements CommandModule<T, McpArgs> {
  public command = 'mcp';
  public describe = 'Start an MCP server exposing studio-bridge tools over stdio';

  public builder = (args: Argv<T>) => {
    return args as Argv<McpArgs>;
  };

  public handler = async (_args: McpArgs) => {
    try {
      await mcpHandlerAsync();
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  };
}
