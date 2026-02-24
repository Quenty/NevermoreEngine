/**
 * `studio-bridge query <path>` -- query the Roblox DataModel.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { BridgeConnection } from '../../bridge/index.js';
import type { SessionContext } from '../../bridge/index.js';
import { queryDataModelHandlerAsync } from '../../commands/query.js';
import type { DataModelNode } from '../../commands/query.js';
import { formatAsJson, formatAsTable, resolveMode } from '../format-output.js';
import type { TableColumn } from '../format-output.js';

export interface QueryArgs extends StudioBridgeGlobalArgs {
  path: string;
  session?: string;
  instance?: string;
  context?: string;
  json?: boolean;
  children?: boolean;
  descendants?: boolean;
  depth?: number;
  properties?: boolean;
  attributes?: boolean;
}

export class QueryCommand<T> implements CommandModule<T, QueryArgs> {
  public command = 'query <path>';
  public describe = 'Query the Roblox DataModel';

  public builder = (args: Argv<T>) => {
    args.positional('path', {
      type: 'string',
      describe: 'Dot-separated path from game (e.g. Workspace.SpawnLocation)',
      demandOption: true,
    });
    args.option('session', {
      alias: 's',
      type: 'string',
      describe: 'Target session ID',
    });
    args.option('instance', {
      type: 'string',
      describe: 'Target instance ID',
    });
    args.option('context', {
      type: 'string',
      describe: 'Target context (edit, client, server)',
    });
    args.option('json', {
      type: 'boolean',
      default: false,
      describe: 'Output as JSON',
    });
    args.option('children', {
      type: 'boolean',
      default: false,
      describe: 'Include direct children',
    });
    args.option('descendants', {
      type: 'boolean',
      default: false,
      describe: 'Include all descendants',
    });
    args.option('depth', {
      type: 'number',
      describe: 'Maximum depth for descendants (default 10)',
    });
    args.option('properties', {
      type: 'boolean',
      default: false,
      describe: 'Include instance properties',
    });
    args.option('attributes', {
      type: 'boolean',
      default: false,
      describe: 'Include instance attributes',
    });

    return args as Argv<QueryArgs>;
  };

  public handler = async (args: QueryArgs) => {
    let connection: BridgeConnection | undefined;
    try {
      connection = await BridgeConnection.connectAsync({
        timeoutMs: args.timeout,
      });
      const session = await connection.resolveSessionAsync(
        args.session,
        args.context as SessionContext | undefined,
        args.instance
      );

      const result = await queryDataModelHandlerAsync(session, {
        path: args.path,
        children: args.children,
        descendants: args.descendants,
        depth: args.depth,
        properties: args.properties,
        attributes: args.attributes,
      });

      const mode = resolveMode({ json: args.json });
      if (mode === 'json') {
        console.log(formatAsJson(result.node));
      } else {
        const rows = [result.node];
        const columns: TableColumn<DataModelNode>[] = [
          { header: 'Name', value: (n) => n.name },
          { header: 'ClassName', value: (n) => n.className },
          { header: 'Path', value: (n) => n.path },
        ];

        console.log(formatAsTable(rows, columns));

        if (
          result.node.properties &&
          Object.keys(result.node.properties).length > 0
        ) {
          console.log('\nProperties:');
          for (const [key, value] of Object.entries(result.node.properties)) {
            console.log(`  ${key}: ${JSON.stringify(value)}`);
          }
        }

        if (
          result.node.attributes &&
          Object.keys(result.node.attributes).length > 0
        ) {
          console.log('\nAttributes:');
          for (const [key, value] of Object.entries(result.node.attributes)) {
            console.log(`  ${key}: ${JSON.stringify(value)}`);
          }
        }

        if (result.node.children && result.node.children.length > 0) {
          console.log(`\nChildren (${result.node.children.length}):`);
          const childColumns: TableColumn<DataModelNode>[] = [
            { header: 'Name', value: (n) => n.name },
            { header: 'ClassName', value: (n) => n.className },
          ];
          console.log(formatAsTable(result.node.children, childColumns));
        }

        OutputHelper.info(result.summary);
      }
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    } finally {
      if (connection) {
        await connection.disconnectAsync();
      }
    }
  };
}
