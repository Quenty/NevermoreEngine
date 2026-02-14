import { getApiKeyAsync, CredentialArgs } from '../auth/credential-store.js';
import { type DeployTarget } from './deploy-config.js';
import { OpenCloudClient } from '../open-cloud/open-cloud-client.js';
import { RateLimiter } from '../open-cloud/rate-limiter.js';
import { type BuildPlaceResult } from './build.js';
import { type TestReporter } from '../testing/reporting/base-test-reporter.js';

export interface UploadPlaceOptions {
  buildResult: BuildPlaceResult;
  args: CredentialArgs & { publish?: boolean };
  client?: OpenCloudClient;
  reporter?: TestReporter;
  packageName?: string;
}

export interface UploadPlaceResult {
  client: OpenCloudClient;
  apiKey: string;
  target: DeployTarget;
  version: number;
}

/**
 * Upload a previously-built .rbxl file to Roblox via Open Cloud.
 * Creates an OpenCloudClient if one is not provided.
 */
export async function uploadPlaceAsync(
  options: UploadPlaceOptions
): Promise<UploadPlaceResult> {
  const { buildResult, args, reporter, packageName } = options;
  let { client } = options;
  const { rbxlPath, target } = buildResult;

  const apiKey = await getApiKeyAsync(args);

  if (!client) {
    client = new OpenCloudClient({
      apiKey,
      rateLimiter: new RateLimiter(),
    });
  }

  reporter?.onPackagePhaseChange(packageName ?? '', 'uploading');
  const version = await client.uploadPlaceAsync(
    target.universeId,
    target.placeId,
    rbxlPath,
    args.publish
  );

  return { client, apiKey, target, version };
}
