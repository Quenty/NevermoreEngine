/**
 * Process-wide output state: whether stdout carries JSON, and warnings about
 * the CLI's own setup (outdated CLI, stale Studio plugin). Text output prints
 * warnings to stderr as they come up. JSON output carries them in the
 * result's `_warnings` field instead, so they are not lost.
 */

import { OutputHelper } from '@quenty/cli-output-helpers';
import type { SessionInfo } from '../bridge/index.js';
import { getPluginBuildVersionAsync } from '../plugin/plugin-build-version.js';

let isJsonOutput = false;
const warnings: string[] = [];

export function setJsonOutput(json: boolean): void {
  isJsonOutput = json;
}

export function isJsonOutputEnabled(): boolean {
  return isJsonOutput;
}

export function addWarning(message: string): void {
  if (warnings.includes(message)) return;
  warnings.push(message);
  if (!isJsonOutput) {
    OutputHelper.warn(message);
  }
}

export function getWarnings(): readonly string[] {
  return warnings;
}

export function clearWarnings(): void {
  warnings.length = 0;
}

export async function warnIfPluginStaleAsync(
  sessions: SessionInfo[]
): Promise<void> {
  const expected = await getPluginBuildVersionAsync();
  for (const session of sessions) {
    if (session.pluginVersion !== expected) {
      addWarning(
        `The studio-bridge plugin in '${session.placeName}' (${session.sessionId}) is out of date. Run 'studio-bridge plugin install' to update it.`
      );
    }
  }
}
