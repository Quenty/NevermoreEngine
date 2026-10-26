/**
 * Runs a script in a Studio launched for the run, through the regular bridge.
 * The place copy carries a launch id that the persistent plugin reports when
 * it registers, so the script runs in that Studio and no other. While the run
 * lasts, the launched Studio is an ordinary session other commands can target.
 */

import { randomUUID } from 'crypto';
import * as path from 'path';
import {
  BuildContext,
  resolvePackagePath,
  resolveTemplatePath,
} from '@quenty/nevermore-template-helpers';
import { BridgeConnection } from '../bridge/index.js';
import type { BridgeSession, ExecResult } from '../bridge/index.js';
import type { StudioBridgePhase } from '../server/studio-bridge-server.js';
import { launchStudioAsync } from '../process/studio-process-manager.js';

const DEFAULT_LAUNCH_TIMEOUT_MS = 120_000;

const defaultProjectPath = resolveTemplatePath(
  import.meta.url,
  path.join('default-test-place', 'default.project.json')
);

const launchIdTransformScript = resolvePackagePath(
  import.meta.url,
  'build-scripts',
  'transform-add-session-attribute.lua'
);

export interface ManagedStudioRunOptions {
  scriptContent: string;
  placePath?: string;
  timeoutMs: number;
  launchTimeoutMs?: number;
  onPhase?: (phase: StudioBridgePhase) => void;
}

export async function runInManagedStudioAsync(
  options: ManagedStudioRunOptions
): Promise<ExecResult> {
  const launchId = randomUUID();
  const buildContext = await BuildContext.createAsync({
    prefix: 'studio-bridge-run-',
  });
  // Kept alive while Studio boots, which takes longer than the idle shutdown
  const connection = await BridgeConnection.connectAsync({ keepAlive: true });
  let killStudioAsync: (() => Promise<void>) | undefined;

  try {
    let sourcePlacePath = options.placePath;
    if (!sourcePlacePath) {
      options.onPhase?.('building');
      sourcePlacePath = buildContext.resolvePath('minimal.rbxl');
      await buildContext.rojoBuildAsync({
        projectPath: defaultProjectPath,
        output: sourcePlacePath,
      });
    }

    // Keep the place's file name, which is what its session id is made from
    const launchedPlacePath = buildContext.resolvePath(
      options.placePath ? path.basename(options.placePath) : 'place.rbxl'
    );
    await buildContext.executeLuneTransformScriptAsync(
      launchIdTransformScript,
      sourcePlacePath,
      launchedPlacePath,
      launchId
    );

    options.onPhase?.('launching');
    const sessionPromise = waitForLaunchedSessionAsync(
      connection,
      launchId,
      options.launchTimeoutMs ?? DEFAULT_LAUNCH_TIMEOUT_MS
    );
    const studio = await launchStudioAsync(launchedPlacePath);
    killStudioAsync = studio.killAsync;

    options.onPhase?.('connecting');
    const session = await sessionPromise;

    options.onPhase?.('executing');
    return await session.execAsync(options.scriptContent, options.timeoutMs);
  } finally {
    await killStudioAsync?.();
    await connection.disconnectAsync();
    await buildContext.cleanupAsync();
  }
}

export function waitForLaunchedSessionAsync(
  connection: BridgeConnection,
  launchId: string,
  timeoutMs: number
): Promise<BridgeSession> {
  return new Promise((resolve, reject) => {
    const findSession = (): BridgeSession | undefined => {
      const info = connection
        .listSessions()
        .find((s) => s.launchId === launchId && s.context === 'edit');
      return info ? connection.getSession(info.sessionId) : undefined;
    };

    const onSession = (): void => {
      const session = findSession();
      if (session) {
        clearTimeout(timer);
        connection.off('session-connected', onSession);
        resolve(session);
      }
    };

    const timer = setTimeout(() => {
      connection.off('session-connected', onSession);
      reject(
        new Error(
          `The launched Studio did not connect within ${timeoutMs}ms. Is the studio-bridge plugin installed?`
        )
      );
    }, timeoutMs);

    connection.on('session-connected', onSession);
    onSession();
  });
}
