/**
 * `action <name>` -- invoke a named Studio action on a connected session.
 *
 * The action name is a positional argument. The plugin is expected to
 * have the action registered (either statically or pushed dynamically).
 * The result is returned as the raw action response payload.
 */

import { defineCommand } from '../framework/define-command.js';
import { arg } from '../framework/arg-builder.js';
import type { BridgeSession } from '../../bridge/index.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ActionResult {
  success: boolean;
  response: unknown;
  summary: string;
}

interface ActionArgs {
  name: string;
  payload?: string;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * Stub — action discovery and generic dispatch are not yet implemented.
 * Returns a structured error explaining the limitation.
 */
export async function invokeActionHandlerAsync(
  _session: BridgeSession,
  actionName: string,
  _payload?: Record<string, unknown>,
): Promise<ActionResult> {
  return {
    success: false,
    response: null,
    summary: `Action '${actionName}' cannot be invoked: the action command is not yet implemented.`,
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const actionCommand = defineCommand<ActionArgs, ActionResult>({
  group: null,
  name: 'action',
  description: 'Invoke a named Studio action on a connected session',
  category: 'execution',
  safety: 'mutate',
  scope: 'session',
  args: {
    name: arg.positional({
      description: 'Name of the action to invoke',
      required: true,
    }),
    payload: arg.option({
      description: 'JSON payload to send with the action',
      alias: 'P',
    }),
  },
  handler: async (session, args) => {
    let payload: Record<string, unknown> | undefined;
    if (args.payload) {
      try {
        payload = JSON.parse(args.payload);
      } catch {
        throw new Error(`Invalid JSON payload: ${args.payload}`);
      }
    }
    return invokeActionHandlerAsync(session, args.name, payload);
  },
  mcp: {
    toolName: 'studio_action',
    mapInput: (input) => ({
      name: input.name as string,
      payload: input.payload as string | undefined,
    }),
    mapResult: (result) => [
      {
        type: 'text' as const,
        text: JSON.stringify({
          success: result.success,
          response: result.response,
        }),
      },
    ],
  },
});
