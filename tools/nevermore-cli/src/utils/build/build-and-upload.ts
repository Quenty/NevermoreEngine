import * as fs from 'fs/promises';
import * as path from 'path';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { getApiKeyAsync, CredentialArgs } from '../auth/credential-store.js';
import {
  DeployTarget,
  loadDeployConfigAsync,
  resolveDeployTarget,
  resolveDeployConfigPath,
} from './deploy-config.js';
import { OpenCloudClient } from '../open-cloud/open-cloud-client.js';
import { RateLimiter } from '../open-cloud/rate-limiter.js';

export interface DeployOverrides {
  universeId?: number;
  placeId?: number;
  scriptTemplate?: string;
  placeFile?: string;
}

export interface BuildAndUploadResult {
  client: OpenCloudClient;
  apiKey: string;
  target: DeployTarget;
  version: number;
  packagePath: string;
}

export async function buildAndUploadAsync(
  args: CredentialArgs & { dryrun: boolean; publish?: boolean } & DeployOverrides,
  targetName: string,
  outputFileName: string = 'build.rbxl',
  packagePath: string = process.cwd(),
  client?: OpenCloudClient
): Promise<BuildAndUploadResult | undefined> {

  const configPath = resolveDeployConfigPath(packagePath);
  const config = await loadDeployConfigAsync(configPath);
  const target = { ...resolveDeployTarget(config, targetName) };

  if (args.universeId) target.universeId = args.universeId;
  if (args.placeId) target.placeId = args.placeId;
  if (args.scriptTemplate) target.scriptTemplate = args.scriptTemplate;

  const apiKey = args.dryrun ? undefined : await getApiKeyAsync(args);

  let rbxlPath: string;

  if (args.placeFile) {
    // Use pre-built place file directly
    rbxlPath = path.resolve(args.placeFile);
    OutputHelper.info(`Using pre-built place file: ${rbxlPath}`);

    if (args.dryrun) {
      return undefined;
    }

    try {
      await fs.access(rbxlPath);
    } catch {
      throw new Error(`Place file not found: ${rbxlPath}`);
    }
  } else {
    // Build via rojo
    const projectPath = path.resolve(packagePath, target.project);
    rbxlPath = path.resolve(packagePath, 'build', outputFileName);

    const packageName = path.basename(packagePath);
    OutputHelper.info(
      `Building rojo project ${packageName}/${target.project}...`
    );

    if (args.dryrun) {
      return undefined;
    }

    await fs.mkdir(path.dirname(rbxlPath), { recursive: true });
    await execa('rojo', ['build', projectPath, '-o', rbxlPath]);
  }

  // Create client if not provided (single-use callers like deploy)
  if (!client) {
    client = new OpenCloudClient({
      apiKey: apiKey!,
      rateLimiter: new RateLimiter(),
    });
  }

  const version = await client.uploadPlaceAsync(
    target.universeId,
    target.placeId,
    rbxlPath,
    args.publish
  );

  return { client, apiKey: apiKey!, target, version, packagePath };
}
