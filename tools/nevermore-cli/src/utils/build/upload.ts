import { getApiKeyAsync, CredentialArgs } from '../auth/credential-store.js';
import { type DeployTarget } from './deploy-config.js';
import { OpenCloudClient } from '../open-cloud/open-cloud-client.js';
import { type BuiltPlace } from './build.js';
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
  const version = await client.uploadPlaceAsync(
    target.universeId,
    target.placeId,
    rbxlPath,
    args.publish
  );

  return { client, apiKey, target, version };
}
