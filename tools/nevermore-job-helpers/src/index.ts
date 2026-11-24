/**
 * Jobs shared by `nevermore` and `studio-bridge`: build a place, deploy it to
 * Roblox or a local Studio, run scripts in it, and clean up.
 *
 * Also: `/place` (building on its own) and `/open-cloud` (the Open Cloud client).
 */
export {
  type BuiltPlace,
  type Deployment,
  type DeployPlaceOptions,
  type JobLogMessage,
  type JobLogs,
  type PlaceJobContext,
  type RunScriptOptions,
  type ScriptJobContext,
  type ScriptRunResult,
} from './jobs/job-context.js';

export {
  BaseJobContext,
  type BaseJobContextOptions,
} from './jobs/base-job-context.js';

export {
  CloudJobContext,
  type CloudJobContextOptions,
} from './jobs/cloud-job-context.js';

export {
  LocalDeployment,
  LocalJobContext,
  LocalPlaceJobContext,
  type LocalPlaceJobContextOptions,
} from './jobs/local-job-context.js';

export {
  type StartStudioSessionOptions,
  type StudioScriptResult,
  type StudioScriptSession,
  type StudioSession,
  type StudioSessionFactory,
} from './jobs/studio-session.js';

export {
  describeLogVolume,
  type LogFetchStats,
} from './jobs/log-fetch-stats.js';

export { type LockFlushResult } from './place/place-build-session.js';
