import {
  type StudioScriptSession,
  type StudioSessionFactory,
} from '@quenty/nevermore-job-helpers';
import { StudioBridgeServer } from '../server/studio-bridge-server.js';

/** Studio sessions that run scripts, and close Studio when the job ends. */
export function createStudioBridgeSessionFactory(): StudioSessionFactory<StudioScriptSession> {
  return {
    async startSessionAsync({ placePath, onPhase }) {
      const bridge = new StudioBridgeServer({
        placePath,
        onPhase: (phase) => {
          // The job reports its own build phases.
          if (phase === 'launching' || phase === 'connecting') {
            onPhase?.(phase);
          }
        },
      });
      await bridge.startAsync();

      return {
        executeAsync: (options) => bridge.executeAsync(options),
        endAsync: () => bridge.stopAsync(),
      };
    },
  };
}
