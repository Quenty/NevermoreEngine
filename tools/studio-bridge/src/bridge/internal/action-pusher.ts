/**
 * Pushes co-located `.luau` action modules to a connected plugin session.
 * Called after a plugin registers with the bridge to dynamically install
 * all action handlers.
 *
 * Uses the `registerAction` request/response protocol message. Each action
 * is sent individually and the result is awaited before proceeding to the
 * next, ensuring deterministic registration order.
 */

import type { ActionSource } from '../../commands/framework/action-loader.js';
import type { BridgeHost } from './bridge-host.js';
import { OutputHelper } from '@quenty/cli-output-helpers';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ActionPushResult {
  name: string;
  success: boolean;
  error?: string;
}

// ---------------------------------------------------------------------------
// Push logic
// ---------------------------------------------------------------------------

/**
 * Push all action sources to a specific plugin session. Returns results
 * for each action (success or failure). Failures are logged but do not
 * abort the remaining pushes.
 */
export async function pushActionsToSessionAsync(
  host: BridgeHost,
  sessionId: string,
  actions: ActionSource[],
): Promise<ActionPushResult[]> {
  const results: ActionPushResult[] = [];

  for (const action of actions) {
    try {
      const response = await host.sendToPluginAsync<{
        type: string;
        payload: {
          name: string;
          success: boolean;
          error?: string;
        };
      }>(
        sessionId,
        {
          type: 'registerAction',
          sessionId,
          requestId: `register-${action.name}-${Date.now()}`,
          payload: {
            name: action.name,
            source: action.source,
          },
        },
        10_000,
      );

      if (response.payload?.success) {
        results.push({ name: action.name, success: true });
      } else {
        const error = response.payload?.error ?? 'Unknown registration error';
        OutputHelper.verbose(
          `[ActionPusher] Failed to register action '${action.name}' on session ${sessionId}: ${error}`,
        );
        results.push({ name: action.name, success: false, error });
      }
    } catch (err) {
      const error = err instanceof Error ? err.message : String(err);
      OutputHelper.verbose(
        `[ActionPusher] Error pushing action '${action.name}' to session ${sessionId}: ${error}`,
      );
      results.push({ name: action.name, success: false, error });
    }
  }

  return results;
}
