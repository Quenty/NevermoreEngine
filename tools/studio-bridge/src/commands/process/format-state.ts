/**
 * Shared coloring helper for StudioState values, used by `process list`
 * and `process info`.
 */

import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioState } from '../../server/web-socket-protocol.js';

export function colorizeState(state: StudioState): string {
  switch (state) {
    case 'Edit':
      return OutputHelper.formatInfo(state);
    case 'Play':
    case 'Run':
      return OutputHelper.formatSuccess(state);
    case 'Paused':
      return OutputHelper.formatWarning(state);
    default:
      return state;
  }
}
