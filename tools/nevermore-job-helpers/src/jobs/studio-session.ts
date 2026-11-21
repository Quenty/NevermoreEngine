import { type JobPhase } from '@quenty/cli-output-helpers/reporting';

/** Studio holding a place open for one deployment. */
export interface StudioSession {
  /** Whether this closes Studio is up to the factory that opened it. */
  endAsync(): Promise<void>;
}

export interface StudioScriptResult {
  success: boolean;
  logs: string;
  returnValues?: unknown[];
}

export interface StudioScriptSession extends StudioSession {
  executeAsync(options: {
    scriptContent: string;
    timeoutMs?: number;
  }): Promise<StudioScriptResult>;
}

export interface StartStudioSessionOptions {
  placePath: string;
  onPhase?: (phase: JobPhase) => void;
}

/** Opens Studio on a place. Injected so this package needn't depend on studio-bridge. */
export interface StudioSessionFactory<S extends StudioSession = StudioSession> {
  startSessionAsync(options: StartStudioSessionOptions): Promise<S>;
}
