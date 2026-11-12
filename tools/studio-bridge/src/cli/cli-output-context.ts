/**
 * Process-wide output state: whether stdout carries JSON, and warnings about
 * the CLI's own setup (outdated CLI, stale Studio plugin). Text output prints
 * warnings to stderr as they come up. JSON output carries them in the
 * result's `_warnings` field instead, so they are not lost.
 */

import { OutputHelper } from '@quenty/cli-output-helpers';
import type { BridgeConnection, SessionInfo } from '../bridge/index.js';
import { getPluginBuildVersionAsync } from '../plugin/plugin-build-version.js';
import { stalePluginWarning } from './plugin-freshness.js';
import { warnUser } from '../messages/warn-user.js';

export {
  clearWarnings,
  getWarnings,
  isJsonOutputEnabled,
  setJsonOutput,
  warnUser,
} from '../messages/warn-user.js';

const reportedHosts = new WeakSet<BridgeConnection>();

export function reportStaleHost(connection: BridgeConnection): void {
  const report = connection.staleHost;
  if (!report || reportedHosts.has(connection)) return;
  reportedHosts.add(connection);
  if (report.replaced) {
    OutputHelper.info(report.message);
  } else {
    warnUser({
      code: 'STALE_HOST',
      message: report.message,
      fix: report.fix,
      cause: report.cause,
    });
  }
}

export async function warnIfPluginStaleAsync(
  sessions: SessionInfo[]
): Promise<void> {
  try {
    const expected = await getPluginBuildVersionAsync();
    for (const session of sessions) {
      if (session.pluginVersion !== expected) {
        warnUser(stalePluginWarning(session));
      }
    }
  } catch (err) {
    warnUser({
      code: 'PLUGIN_VERSION_UNKNOWN',
      message: "Couldn't check whether the studio-bridge plugin is up to date.",
      fix: 'Reinstall @quenty/studio-bridge if this keeps happening.',
      cause: err,
    });
  }
}
