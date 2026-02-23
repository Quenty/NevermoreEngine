import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import {
  type LuauTask,
  type OpenCloudClient,
} from '../open-cloud/open-cloud-client.js';
import { tryRenamePlaceAsync } from '../auth/roblox-auth/index.js';
import { buildPlaceNameAsync, timeoutAsync } from '../nevermore-cli-utils.js';
import {
  type Deployment,
  type DeployPlaceOptions,
  type RunScriptOptions,
  type ScriptRunResult,
} from './job-context.js';
import { BaseJobContext } from './base-job-context.js';

const SKIP_RENAMING_PLACE = true;

class CloudDeployment implements Deployment {
  universeId: number;
  placeId: number;
  version: number;
  taskPath?: string;
  taskState?: LuauTask['state'];

  constructor(universeId: number, placeId: number, version: number) {
    this.universeId = universeId;
    this.placeId = placeId;
    this.version = version;
  }
}

export class CloudJobContext extends BaseJobContext {
  constructor(reporter: Reporter, openCloudClient: OpenCloudClient) {
    super(reporter, openCloudClient);
  }

  async deployBuiltPlaceAsync(
    options: DeployPlaceOptions
  ): Promise<Deployment> {
    const { builtPlace, packageName, packagePath } = options;
    const { rbxlPath, target } = builtPlace;

    this._reporter.onPackagePhaseChange(packageName, 'uploading');

    const version = await this._openCloudClient!.uploadPlaceAsync(
      target.universeId,
      target.placeId,
      rbxlPath,
      undefined,
      (transferred, total) => {
        this._reporter.onPackageProgressUpdate(packageName, {
          kind: 'bytes',
          transferredBytes: transferred,
          totalBytes: total,
        });
      }
    );

    // Eagerly release build artifacts after upload (disposeAsync is safety net)
    await this.releaseBuiltPlaceAsync(builtPlace);

    // Best-effort rename to reflect current package + commit
    if (!SKIP_RENAMING_PLACE) {
      const placeName = await buildPlaceNameAsync(packagePath);
      await tryRenamePlaceAsync(target.placeId, placeName);
    }

    return new CloudDeployment(target.universeId, target.placeId, version);
  }

  async runScriptAsync(
    deployment: Deployment,
    options: RunScriptOptions
  ): Promise<ScriptRunResult> {
    const cloudDeployment = deployment as CloudDeployment;
    const { scriptContent, packageName, timeoutMs = 120_000 } = options;

    this._reporter.onPackagePhaseChange(packageName, 'scheduling');
    const task = await this._openCloudClient!.createExecutionTaskAsync(
      cloudDeployment.universeId,
      cloudDeployment.placeId,
      cloudDeployment.version,
      scriptContent
    );

    let pollCount = 0;
    const completedTask = await Promise.race([
      this._openCloudClient!.pollTaskCompletionAsync(task.path, (state) => {
        pollCount++;
        if (state === 'PROCESSING') {
          this._reporter.onPackagePhaseChange(packageName, 'executing');
        }
        const label = state === 'QUEUED' ? 'queued' : `poll #${pollCount}`;
        this._reporter.onPackageProgressUpdate(packageName, {
          kind: 'steps',
          completed: pollCount,
          total: 0,
          label,
        });
      }),
      timeoutAsync(timeoutMs, `Test timed out after ${timeoutMs / 1000}s`),
    ]);

    cloudDeployment.taskPath = task.path;
    cloudDeployment.taskState = completedTask.state;

    return { success: completedTask.state === 'COMPLETE' };
  }

  async getLogsAsync(deployment: Deployment): Promise<string> {
    const cloudDeployment = deployment as CloudDeployment;

    if (!cloudDeployment.taskPath) {
      throw new Error('No task has been run yet');
    }

    const logs = await this._openCloudClient!.getRawTaskLogsAsync(
      cloudDeployment.taskPath
    );

    if (cloudDeployment.taskState && cloudDeployment.taskState !== 'COMPLETE') {
      return [logs, `Task ended with state: ${cloudDeployment.taskState}`]
        .filter(Boolean)
        .join('\n');
    }

    return logs;
  }

  async releaseAsync(_deployment: Deployment): Promise<void> {
    // No-op for cloud — place stays on cloud, task metadata discarded with the handle.
  }

  async disposeAsync(): Promise<void> {
    await super.disposeAsync();
  }
}
