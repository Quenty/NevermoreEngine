import {
  getTaskReturnValues,
  type LuauTask,
  type OpenCloudClient,
} from '../open-cloud/open-cloud-client.js';
import { reportRateLimitWait } from '../open-cloud/rate-limiter.js';
import {
  BaseJobContext,
  type BaseJobContextOptions,
} from './base-job-context.js';
import {
  type Deployment,
  type DeployPlaceOptions,
  type JobLogs,
  type RunScriptOptions,
  type ScriptJobContext,
  type ScriptRunResult,
} from './job-context.js';

export interface CloudJobContextOptions
  extends Omit<BaseJobContextOptions, 'downloader'> {
  /** Also downloads base places. */
  openCloudClient: OpenCloudClient;
}

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

/** Uploads places and runs scripts as Open Cloud Luau execution tasks. */
export class CloudJobContext
  extends BaseJobContext
  implements ScriptJobContext
{
  private _openCloudClient: OpenCloudClient;

  constructor(options: CloudJobContextOptions) {
    super({ ...options, downloader: options.openCloudClient });
    this._openCloudClient = options.openCloudClient;
  }

  async deployBuiltPlaceAsync(
    options: DeployPlaceOptions
  ): Promise<Deployment> {
    const { builtPlace, packageName } = options;
    const { rbxlPath, target } = builtPlace;

    this._reporter.onPackagePhaseChange(packageName, 'uploading');

    const version = await this._openCloudClient.uploadPlaceAsync(
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
      },
      reportRateLimitWait(this._reporter, packageName)
    );

    // Eagerly release build artifacts after upload (disposeAsync is safety net)
    await this.releaseBuiltPlaceAsync(builtPlace);

    return new CloudDeployment(target.universeId, target.placeId, version);
  }

  async runScriptAsync(
    deployment: Deployment,
    options: RunScriptOptions
  ): Promise<ScriptRunResult> {
    const cloudDeployment = deployment as CloudDeployment;
    const { scriptContent, packageName, timeoutMs = 120_000 } = options;

    const onRateLimitWait = reportRateLimitWait(this._reporter, packageName);

    this._reporter.onPackagePhaseChange(packageName, 'scheduling');
    const task = await this._openCloudClient.createExecutionTaskAsync(
      cloudDeployment.universeId,
      cloudDeployment.placeId,
      cloudDeployment.version,
      scriptContent,
      timeoutMs,
      onRateLimitWait
    );

    // Give the server-side timeout a head start so we observe the cancelled
    // task state instead of bailing out on the client first.
    const CLIENT_TIMEOUT_GRACE_MS = 30_000;

    let pollCount = 0;
    const completedTask = await Promise.race([
      this._openCloudClient.pollTaskCompletionAsync(
        task.path,
        (state) => {
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
        },
        onRateLimitWait
      ),
      timeoutAsync(
        timeoutMs + CLIENT_TIMEOUT_GRACE_MS,
        `Script timed out after ${timeoutMs / 1000}s`
      ),
    ]);

    cloudDeployment.taskPath = task.path;
    cloudDeployment.taskState = completedTask.state;

    // Surface error details from the Roblox API when the task didn't complete
    let errorMessage: string | undefined;
    if (completedTask.state !== 'COMPLETE') {
      const parts: string[] = [`Task ended with state: ${completedTask.state}`];
      if (completedTask.error?.message) {
        parts.push(`Error: ${completedTask.error.message}`);
      }
      if (completedTask.error?.code) {
        parts.push(`Code: ${completedTask.error.code}`);
      }
      errorMessage = parts.join('. ');
    }

    return {
      success: completedTask.state === 'COMPLETE',
      taskState: completedTask.state,
      errorMessage,
      returnValues: getTaskReturnValues(completedTask),
    };
  }

  async getLogsAsync(deployment: Deployment): Promise<JobLogs> {
    const cloudDeployment = deployment as CloudDeployment;

    if (!cloudDeployment.taskPath) {
      throw new Error('No task has been run yet');
    }

    const fetched = await this._openCloudClient.getRawTaskLogsAsync(
      cloudDeployment.taskPath
    );

    if (cloudDeployment.taskState && cloudDeployment.taskState !== 'COMPLETE') {
      const note = `Task ended with state: ${cloudDeployment.taskState}`;
      return {
        text: [fetched.text, note].filter(Boolean).join('\n'),
        messages: [...fetched.messages, { message: note }],
        stats: fetched.stats,
      };
    }

    return fetched;
  }

  async releaseAsync(_deployment: Deployment): Promise<void> {
    // No-op for cloud — place stays on cloud, task metadata discarded with the handle.
  }
}

function timeoutAsync(ms: number, message: string): Promise<never> {
  return new Promise<never>((_, reject) =>
    setTimeout(() => reject(new Error(message)), ms)
  );
}
