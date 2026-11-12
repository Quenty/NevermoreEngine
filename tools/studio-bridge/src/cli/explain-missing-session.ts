import type { BridgeConnection } from '../bridge/index.js';
import { SessionNotFoundError } from '../bridge/index.js';
import { NO_STUDIO_CONNECTED } from '../bridge/types.js';
import { explainMissingPlaytestContextAsync } from '../commands/playtest/playtest-sessions.js';
import { StudioBridgeError } from '../messages/studio-bridge-error.js';
import { isPersistentPluginInstalled } from '../plugin/plugin-discovery.js';
import {
  listStudioProcessesAsync,
  type RunningStudioProcess,
} from '../process/studio-process-closer.js';

export interface StudioSetup {
  isRemote: boolean;
  listStudiosAsync: () => Promise<RunningStudioProcess[]>;
  isPluginInstalled: () => boolean;
}

export async function explainMissingSessionAsync(
  connection: BridgeConnection,
  err: unknown,
  setup: StudioSetup = {
    isRemote: connection.isRemote,
    listStudiosAsync: listStudioProcessesAsync,
    isPluginInstalled: isPersistentPluginInstalled,
  }
): Promise<unknown> {
  if (err instanceof SessionNotFoundError && err.code === NO_STUDIO_CONNECTED) {
    return explainNoStudioAsync(setup, err);
  }
  return explainMissingPlaytestContextAsync(connection, err);
}

export async function explainNoStudioAsync(
  setup: StudioSetup,
  cause?: unknown
): Promise<StudioBridgeError> {
  const studios = setup.isRemote
    ? undefined
    : await setup.listStudiosAsync().catch(() => undefined);

  if (studios?.length === 0) {
    return new StudioBridgeError({
      code: NO_STUDIO_CONNECTED,
      message: "Roblox Studio isn't open.",
      fix: "Open a place in Studio, or run 'studio-bridge process launch'.",
      cause,
    });
  }
  if (studios && !safelyIsPluginInstalled(setup)) {
    return new StudioBridgeError({
      code: NO_STUDIO_CONNECTED,
      message:
        "Studio is open, but the studio-bridge plugin isn't installed, so nothing connects to it.",
      fix: "Run 'studio-bridge plugin install'.",
      cause,
    });
  }
  if (studios) {
    return new StudioBridgeError({
      code: NO_STUDIO_CONNECTED,
      message: "Studio is open, but the studio-bridge plugin hasn't connected.",
      fix: 'Check the plugin is enabled under Plugins > Manage Plugins in Studio, then run the command again.',
      cause,
    });
  }
  return new StudioBridgeError({
    code: NO_STUDIO_CONNECTED,
    message: 'No Studio is connected to studio-bridge.',
    fix: "Open a place in Studio with the studio-bridge plugin installed ('studio-bridge plugin install').",
    cause,
  });
}

function safelyIsPluginInstalled(setup: StudioSetup): boolean {
  try {
    return setup.isPluginInstalled();
  } catch {
    return true;
  }
}
