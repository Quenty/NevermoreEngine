import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { type BasePlaceResolver } from '@quenty/nevermore-deploy';
import {
  type BuildPlaceOptions,
  type BuiltPlace,
} from '../place/build-place.js';
import { type PlaceDownloader } from '../place/merge-base-place.js';
import {
  PlaceBuildSession,
  type LockFlushResult,
} from '../place/place-build-session.js';
import {
  type Deployment,
  type DeployPlaceOptions,
  type PlaceJobContext,
} from './job-context.js';

export interface BaseJobContextOptions {
  reporter: Reporter;
  /** Without one, building a target with a `basePlace` fails. */
  downloader?: PlaceDownloader;
  basePlaceResolver?: BasePlaceResolver;
  /** Appended when a base place can't be downloaded. */
  missingCredentialsHint?: string;
  /** Called on dispose when there is a resolver. */
  onLockFlushed?: (result: LockFlushResult) => void;
}

/**
 * Abstract base for job contexts. Building goes through a `PlaceBuildSession`,
 * which cleans up every built place and writes the lock file on dispose.
 */
export abstract class BaseJobContext implements PlaceJobContext {
  protected _reporter: Reporter;
  private _buildSession: PlaceBuildSession;
  private _hasResolver: boolean;
  private _onLockFlushed: ((result: LockFlushResult) => void) | undefined;

  constructor(options: BaseJobContextOptions) {
    this._reporter = options.reporter;
    this._hasResolver = options.basePlaceResolver !== undefined;
    this._onLockFlushed = options.onLockFlushed;
    this._buildSession = new PlaceBuildSession({
      reporter: options.reporter,
      downloader: options.downloader,
      resolver: options.basePlaceResolver,
      missingCredentialsHint: options.missingCredentialsHint,
    });
  }

  buildPlaceAsync(options: BuildPlaceOptions): Promise<BuiltPlace> {
    return this._buildSession.buildPlaceAsync(options);
  }

  releaseBuiltPlaceAsync(builtPlace: BuiltPlace): Promise<void> {
    return this._buildSession.releaseBuiltPlaceAsync(builtPlace);
  }

  abstract deployBuiltPlaceAsync(
    options: DeployPlaceOptions
  ): Promise<Deployment>;
  abstract releaseAsync(deployment: Deployment): Promise<void>;

  async disposeAsync(): Promise<void> {
    const result = await this._buildSession.disposeAsync();
    if (this._hasResolver) {
      this._onLockFlushed?.(result);
    }
  }
}
