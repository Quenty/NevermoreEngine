/**
 * Everything that reads or writes `deploy.nevermore.json`.
 *
 * This package is the single owner of the deploy config format. It is schema
 * and policy only — no network, no CLI framework, and no file access beyond the
 * config files themselves — so the rules stay identical no matter which command
 * (or which repo) is asking.
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
