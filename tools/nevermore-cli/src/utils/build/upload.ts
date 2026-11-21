import {
  getApiKeyAsync,
  type CredentialArgs,
} from '@quenty/nevermore-cli-helpers';
import { type DeployTarget } from '@quenty/nevermore-deploy';
import { type BuiltPlace } from '@quenty/nevermore-job-helpers';
import {
  OpenCloudClient,
  reportRateLimitWait,
} from '@quenty/nevermore-job-helpers/open-cloud';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';

export interface UploadPlaceOptions {
  builtPlace: BuiltPlace;
  args: CredentialArgs & { publish?: boolean };
  client: OpenCloudClient;
  reporter?: Reporter;
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
  const { builtPlace, args, reporter, packageName } = options;
  let { client } = options;
  const { rbxlPath, target } = builtPlace;

  const apiKey = await getApiKeyAsync(args);

  reporter?.onPackagePhaseChange(packageName ?? '', 'uploading');

  const onProgress =
    reporter && packageName
      ? (transferred: number, total: number) => {
          reporter.onPackageProgressUpdate(packageName, {
            kind: 'bytes',
            transferredBytes: transferred,
            totalBytes: total,
          });
        }
      : undefined;

  const version = await client.uploadPlaceAsync(
    target.universeId,
    target.placeId,
    rbxlPath,
    args.publish,
    onProgress,
    reporter && packageName
      ? reportRateLimitWait(reporter, packageName)
      : undefined
  );

  return { client, apiKey, target, version };
}
