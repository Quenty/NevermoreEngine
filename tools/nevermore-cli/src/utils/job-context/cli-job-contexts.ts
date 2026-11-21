import { OutputHelper } from '@quenty/cli-output-helpers';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { type BasePlaceResolver } from '@quenty/nevermore-deploy';
import {
  CloudJobContext,
  LocalJobContext,
  type LockFlushResult,
} from '@quenty/nevermore-job-helpers';
import { type OpenCloudClient } from '@quenty/nevermore-job-helpers/open-cloud';
import { createStudioBridgeSessionFactory } from '@quenty/studio-bridge';

const MISSING_CREDENTIALS_HINT = 'Re-run with --cloud, or pass --api-key.';

export interface CliJobContextOptions {
  reporter: Reporter;
  basePlaceResolver?: BasePlaceResolver;
}

export function createCloudJobContext(
  options: CliJobContextOptions & { client: OpenCloudClient }
): CloudJobContext {
  return new CloudJobContext({
    reporter: options.reporter,
    openCloudClient: options.client,
    basePlaceResolver: options.basePlaceResolver,
    missingCredentialsHint: MISSING_CREDENTIALS_HINT,
    onLockFlushed: reportLockFlush,
  });
}

export function createLocalJobContext(
  options: CliJobContextOptions & { client?: OpenCloudClient }
): LocalJobContext {
  return new LocalJobContext({
    reporter: options.reporter,
    downloader: options.client,
    basePlaceResolver: options.basePlaceResolver,
    missingCredentialsHint: MISSING_CREDENTIALS_HINT,
    onLockFlushed: reportLockFlush,
    studio: createStudioBridgeSessionFactory(),
  });
}

function reportLockFlush(result: LockFlushResult): void {
  const { writtenLockPaths, lockWriteError, lockMode } = result;
  for (const lockPath of writtenLockPaths) {
    OutputHelper.info(`Updated ${lockPath}`);
  }
  // A refreshed pin only survives if the lock is committed. Nothing here
  // commits it, so on a CI runner the file is written and then thrown
  // away — and the next build that does not refresh reads the old
  // version out of the repo and republishes the base place this run just
  // moved past. Silent, and it looks like the watch never fired.
  if (writtenLockPaths.length > 0 && lockMode === 'refresh') {
    OutputHelper.warn(
      `--refresh-base-place moved ${writtenLockPaths.length} lock file${
        writtenLockPaths.length === 1 ? '' : 's'
      }. Commit the change, or the next build without ` +
        `--refresh-base-place will rebuild the previous base place ` +
        `version and revert this deploy.`
    );
  }
  if (lockWriteError !== undefined) {
    OutputHelper.warn(
      `Could not write the deploy lock file: ${
        lockWriteError instanceof Error
          ? lockWriteError.message
          : String(lockWriteError)
      }`
    );
  }
}
