/**
 * Lifecycle helpers that wrap the BridgeConnection connect/disconnect
 * boilerplate shared by all CLI commands.
 */

import { Argv } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { BridgeConnection } from '../bridge/index.js';
import type { SessionContext, BridgeSession } from '../bridge/index.js';
import type { StudioBridgeGlobalArgs } from './args/global-args.js';

/** Shared yargs options for session-targeting commands. */
export interface SessionCommandOptions {
  session?: string;
  instance?: string;
  context?: string;
  json?: boolean;
}

export interface ConnectionArgs extends StudioBridgeGlobalArgs {
  json?: boolean;
}

export interface SessionArgs extends ConnectionArgs, SessionCommandOptions {}

/**
 * Add the 4 shared session-targeting yargs options (--session, --instance,
 * --context, --json) to a command builder.
 */
export function addSessionOptions<T>(args: Argv<T>): Argv<T & SessionCommandOptions> {
  args.option('session',  { alias: 's', type: 'string',  describe: 'Target session ID' });
  args.option('instance', { type: 'string',  describe: 'Target instance ID' });
  args.option('context',  { type: 'string',  describe: 'Target context (edit, client, server)' });
  args.option('json',     { type: 'boolean', default: false, describe: 'Output as JSON' });
  return args as Argv<T & SessionCommandOptions>;
}

/**
 * Connect to the bridge, resolve a session, call `fn`, then disconnect.
 * On error: prints via `OutputHelper.error()` and exits with code 1.
 */
export async function withSessionAsync<T>(
  args: SessionArgs,
  fn: (session: BridgeSession) => Promise<T>,
): Promise<T> {
  let connection: BridgeConnection | undefined;
  try {
    connection = await BridgeConnection.connectAsync({
      timeoutMs: args.timeout,
      remoteHost: args.remote,
      local: args.local,
    });
    const session = await connection.resolveSessionAsync(
      args.session,
      args.context as SessionContext | undefined,
      args.instance,
    );

    return await fn(session);
  } catch (err) {
    OutputHelper.error(err instanceof Error ? err.message : String(err));
    return process.exit(1) as never;
  } finally {
    if (connection) await connection.disconnectAsync();
  }
}

/**
 * Connect to the bridge, call `fn` with the connection, then disconnect.
 * For commands that operate on the connection itself (e.g. `sessions`).
 */
export async function withConnectionAsync<T>(
  args: ConnectionArgs,
  connectOptions: { waitForSessions?: boolean },
  fn: (connection: BridgeConnection) => Promise<T>,
): Promise<T> {
  let connection: BridgeConnection | undefined;
  try {
    connection = await BridgeConnection.connectAsync({
      timeoutMs: args.timeout,
      remoteHost: args.remote,
      local: args.local,
      waitForSessions: connectOptions.waitForSessions,
    });

    return await fn(connection);
  } catch (err) {
    OutputHelper.error(err instanceof Error ? err.message : String(err));
    return process.exit(1) as never;
  } finally {
    if (connection) await connection.disconnectAsync();
  }
}
