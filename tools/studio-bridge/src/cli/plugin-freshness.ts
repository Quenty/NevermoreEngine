import { createInterface } from 'readline/promises';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type {
  BridgeConnection,
  BridgeSession,
  SessionInfo,
} from '../bridge/index.js';
import { getPluginBuildVersionAsync } from '../plugin/plugin-build-version.js';
import { installPersistentPluginAsync } from '../plugin/persistent-plugin-installer.js';
import {
  StudioBridgeError,
  type StudioBridgeErrorOptions,
} from '../messages/studio-bridge-error.js';
import type { UserWarning } from '../messages/warn-user.js';

export const PLUGIN_RELOAD_TIMEOUT_MS = 15_000;
const RELOAD_POLL_MS = 250;

export const PLUGIN_UPDATE_FIX =
  'Run the command again with --update-plugin, which updates it and goes on.';

const PLAYTEST_PLUGIN_FIX =
  "Run 'studio-bridge plugin install', then 'studio-bridge playtest restart'.";

const DECLINED_PLUGIN_FIX =
  "Run 'studio-bridge plugin install' when you want to update it.";

const REMOTE_PLUGIN_FIX =
  "Run 'studio-bridge plugin install' on the machine Studio runs on.";

const STALE_PLUGIN_CONSEQUENCE = ', so some commands may fail';

export type PluginUpdatePolicy = 'prompt' | 'update' | 'error';

let policy: PluginUpdatePolicy = 'error';

export function setPluginUpdatePolicy(value: PluginUpdatePolicy): void {
  policy = value;
}

export function getPluginUpdatePolicy(): PluginUpdatePolicy {
  return policy;
}

export function resolvePluginUpdatePolicy(options: {
  updatePlugin?: boolean;
  json?: boolean;
  stdinIsTTY?: boolean;
  stderrIsTTY?: boolean;
}): PluginUpdatePolicy {
  if (options.updatePlugin) return 'update';
  if (options.stdinIsTTY && options.stderrIsTTY && !options.json) {
    return 'prompt';
  }
  return 'error';
}

export class PluginOutdatedError extends StudioBridgeError {
  constructor(options: Omit<StudioBridgeErrorOptions, 'code'>) {
    super({ code: 'PLUGIN_OUTDATED', ...options });
    this.name = 'PluginOutdatedError';
  }
}

export function formatPluginVersion(version: string): string {
  return version ? version.slice(0, 6) : 'an unversioned build';
}

function describeOutdatedPlugin(
  info: Pick<SessionInfo, 'placeName' | 'context'>
): string {
  const where =
    info.context === 'edit'
      ? `'${info.placeName}'`
      : `the playtest of '${info.placeName}'`;
  return `The studio-bridge plugin in ${where} is out of date`;
}

function describeVersions(installed: string, expected: string): string {
  return `Installed plugin build ${formatPluginVersion(
    installed
  )}, this CLI needs ${formatPluginVersion(expected)}`;
}

export function stalePluginWarning(
  info: Pick<SessionInfo, 'placeName' | 'pluginVersion' | 'context'>
): UserWarning {
  return {
    code: 'PLUGIN_OUTDATED',
    message: `${describeOutdatedPlugin(info)}${STALE_PLUGIN_CONSEQUENCE}.`,
    fix:
      info.context === 'edit'
        ? "Run 'studio-bridge plugin install'."
        : PLAYTEST_PLUGIN_FIX,
  };
}

export interface PluginFreshnessDeps {
  getExpectedVersionAsync: () => Promise<string>;
  installAsync: () => Promise<unknown>;
  confirmAsync: (question: string) => Promise<boolean>;
  log: (message: string) => void;
  reloadTimeoutMs: number;
}

const defaultDeps: PluginFreshnessDeps = {
  getExpectedVersionAsync: getPluginBuildVersionAsync,
  installAsync: installPersistentPluginAsync,
  confirmAsync: confirmOnTerminalAsync,
  log: (message) => OutputHelper.info(message),
  reloadTimeoutMs: PLUGIN_RELOAD_TIMEOUT_MS,
};

export async function ensureCurrentPluginAsync(
  connection: BridgeConnection,
  session: BridgeSession,
  overrides: Partial<PluginFreshnessDeps> = {}
): Promise<BridgeSession> {
  const deps = { ...defaultDeps, ...overrides };
  const expected = await deps.getExpectedVersionAsync();
  if (session.info.pluginVersion === expected) {
    return session;
  }

  const description = `${describeOutdatedPlugin(session.info)}.`;
  const outdated = (fix: string, message = description) =>
    new PluginOutdatedError({
      message,
      fix,
      cause: describeVersions(session.info.pluginVersion, expected),
    });
  if (connection.isRemote) {
    throw outdated(REMOTE_PLUGIN_FIX);
  }
  if (session.context !== 'edit') {
    throw outdated(PLAYTEST_PLUGIN_FIX);
  }

  const current = getPluginUpdatePolicy();
  if (current === 'error') {
    throw outdated(PLUGIN_UPDATE_FIX);
  }
  if (current === 'prompt') {
    if (!(await deps.confirmAsync(`${description}\nUpdate it now? [Y/n] `))) {
      throw outdated(
        DECLINED_PLUGIN_FIX,
        "Didn't run the command, since the studio-bridge plugin is out of date."
      );
    }
  } else {
    deps.log(`${description} Updating it.`);
  }

  const placeName = session.info.placeName;
  await deps.installAsync();
  deps.log(
    `Installed the studio-bridge plugin. Waiting for '${placeName}' to reload it...`
  );

  const [reload] = await waitForPluginReloadAsync(
    connection,
    [session.info],
    expected,
    deps.reloadTimeoutMs
  );
  if (!reload.session) {
    throw new StudioBridgeError({
      code: 'PLUGIN_RELOAD_TIMEOUT',
      message: `Updated the studio-bridge plugin, but '${placeName}' didn't reload it within ${
        deps.reloadTimeoutMs / 1000
      }s.`,
      fix: `Reopen '${placeName}' in Studio, then run the command again.`,
    });
  }
  deps.log(`'${placeName}' reloaded the plugin.`);
  return reload.session;
}

export interface PluginReload {
  sessionId: string;
  placeName: string;
  session?: BridgeSession;
}

export async function waitForPluginReloadAsync(
  connection: BridgeConnection,
  sessions: SessionInfo[],
  expected: string,
  timeoutMs: number
): Promise<PluginReload[]> {
  const results: PluginReload[] = sessions.map((info) => ({
    sessionId: info.sessionId,
    placeName: info.placeName,
  }));
  const deadline = Date.now() + timeoutMs;

  while (true) {
    const live = connection.listSessions();
    sessions.forEach((info, index) => {
      if (results[index].session) return;
      const match =
        live.find(
          (s) => s.sessionId === info.sessionId && s.pluginVersion === expected
        ) ??
        live.find(
          (s) =>
            s.instanceId === info.instanceId &&
            s.context === info.context &&
            s.pluginVersion === expected
        );
      const session = match && connection.getSession(match.sessionId);
      if (session && session.info.pluginVersion === expected) {
        results[index].session = session;
      }
    });

    if (results.every((r) => r.session) || Date.now() >= deadline) {
      return results;
    }
    await new Promise((resolve) => setTimeout(resolve, RELOAD_POLL_MS));
  }
}

async function confirmOnTerminalAsync(question: string): Promise<boolean> {
  const readline = createInterface({
    input: process.stdin,
    output: process.stderr,
  });
  try {
    const answer = (await readline.question(question)).trim().toLowerCase();
    return answer === '' || answer === 'y' || answer === 'yes';
  } finally {
    readline.close();
  }
}
