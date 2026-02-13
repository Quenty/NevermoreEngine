import * as fs from 'fs/promises';
import * as path from 'path';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { getApiKeyAsync, CredentialArgs } from './credential-store.js';
import {
  DeployTarget,
  loadDeployConfigAsync,
  resolveTarget,
  resolveDeployConfigPath,
} from './deploy-config.js';
import { uploadPlaceAsync } from './open-cloud-client.js';

export interface DeployOverrides {
  universeId?: number;
  placeId?: number;
  script?: string;
}

export interface BuildAndUploadResult {
  apiKey: string;
  target: DeployTarget;
  version: number;
  packagePath: string;
}

export async function buildAndUploadAsync(
  args: CredentialArgs & { dryrun: boolean; publish?: boolean } & DeployOverrides,
  targetName: string,
  outputFileName: string = 'build.rbxl'
): Promise<BuildAndUploadResult | undefined> {
  const packagePath = process.cwd();

  const configPath = resolveDeployConfigPath(packagePath);
  const config = await loadDeployConfigAsync(configPath);
  const target = { ...resolveTarget(config, targetName) };

  if (args.universeId) target.universeId = args.universeId;
  if (args.placeId) target.placeId = args.placeId;
  if (args.script) target.script = args.script;

  const apiKey = args.dryrun ? undefined : await getApiKeyAsync(args);

  const projectPath = path.resolve(packagePath, target.project);
  const outputPath = path.resolve(packagePath, 'build', outputFileName);

  const packageName = path.basename(packagePath);
  OutputHelper.info(
    `Building rojo project ${packageName}/${target.project}...`
  );
  if (args.dryrun) {
    return undefined;
  }
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await execa('rojo', ['build', projectPath, '-o', outputPath]);

  const version = await uploadPlaceAsync(
    apiKey!,
    target.universeId,
    target.placeId,
    outputPath,
    args.publish
  );

  return { apiKey: apiKey!, target, version, packagePath };
}
