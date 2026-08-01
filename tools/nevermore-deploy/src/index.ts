/**
 * The deploy config format, and the rules that read it.
 *
 * This package is the single owner of `deploy.nevermore.json` and its lock
 * file: schema, validation, target selectors, base place version resolution,
 * and watch policy. Schema and policy only — no network, no CLI framework, and
 * no file access beyond the config files themselves — so the rules stay
 * identical no matter which command, or which repo, is asking.
 *
 * It reaches the outside world through three ports, each implemented in the
 * CLI: `PlaceVersionSource`, `WatchRegistry`, and `WatchStream`. The watch
 * types are declared here so the vocabulary a config implies and the vocabulary
 * sent to a watch service cannot drift apart.
 */
export {
  BASE_PLACE_VERSION_KEYWORDS,
  discoverUniverseIdAsync,
  isBasePlaceVersionKeyword,
  loadDeployConfigAsync,
  resolveDefaultTargetName,
  resolveDeployConfigPath,
  resolveDeployTargetPlaces,
  resolveSingleDeployTarget,
  toManifestPlaceInfo,
  type BasePlaceConfig,
  type BasePlaceVersion,
  type BasePlaceVersionKeyword,
  type DeployConfig,
  type DeployTarget,
  type DeployTargetConfig,
  type ManifestPlaceInfo,
  type MultiPlaceTargetConfig,
} from './deploy-config.js';

export {
  BasePlaceResolver,
  type BasePlaceResolverOptions,
} from './base-place-resolver.js';

export {
  DEPLOY_LOCK_VERSION,
  createEmptyDeployLock,
  loadDeployLockAsync,
  resolveDeployLockPath,
  saveDeployLockAsync,
  type BasePlaceLockEntry,
  type DeployLock,
} from './deploy-lock.js';

export { type PlaceVersionSource } from './place-version-source.js';

export {
  formatTargetSelector,
  parseTargetSelector,
  type TargetSelector,
} from './target-selector.js';

export {
  WATCH_BASELINE_KIND,
  WATCH_INPUT_NAME,
  WATCH_MODES,
  buildWatchMonitorName,
  buildWatchPlan,
  checkBasePlaceWatchable,
  describeWatchPlanSkip,
  parseWatchDuration,
  parseWatchOption,
  resolveWatchDelivery,
  sanitizeWatchName,
  type WatchAction,
  type WatchDelivery,
  type WatchEntry,
  type WatchMode,
  type WatchNotifyAction,
  type WatchOption,
  type WatchPlan,
  type WatchPlanEntry,
  type WatchPlanOptions,
  type WatchPlanSkip,
  type WatchRegistrationRequest,
  type WatchRegistrationResult,
  type WatchRegistry,
  type WatchSource,
  type WatchTriggerOutcome,
  type WatchTriggerResult,
  type WatchWorkflowDispatchAction,
} from './watch-config.js';

export {
  type WatchStream,
  type WatchStreamEnding,
  type WatchStreamEvent,
  type WatchStreamHandlers,
  type WatchStreamNotify,
  type WatchStreamOptions,
  type WatchStreamReady,
  type WatchStreamResult,
  type WatchStreamStatus,
} from './watch-stream.js';
