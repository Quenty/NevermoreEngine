import * as fs from 'fs/promises';
import { type LuauTask, OpenCloudClient } from '../open-cloud/open-cloud-client.js';
import { tryRenamePlaceAsync } from '../auth/roblox-auth/index.js';
import { buildPlaceNameAsync, timeoutAsync } from '../nevermore-cli-utils.js';
import {
  type JobContext,
  type DeployPlaceOptions,
  type RunScriptOptions,
  type ScriptRunResult,
} from './job-context.js';

export class CloudJobContext implements JobContext {
  private _client: OpenCloudClient;
  private _universeId = 0;
  private _placeId = 0;
  private _version = 0;
  private _taskPath: string | undefined;
  private _taskState: LuauTask['state'] | undefined;

  constructor(options: { client: OpenCloudClient }) {
    this._client = options.client;
  }

  async deployBuiltPlaceAsync(options: DeployPlaceOptions): Promise<void> {
    const { rbxlPath, deployTarget, reporter, packageName, packagePath } =
      options;

    if (!deployTarget) {
      throw new Error(
        'CloudJobContext requires a deployTarget with universeId and placeId'
      );
    }

    this._universeId = deployTarget.universeId;
    this._placeId = deployTarget.placeId;

    reporter.onPackagePhaseChange(packageName, 'uploading');
    this._version = await this._client.uploadPlaceAsync(
      this._universeId,
      this._placeId,
      rbxlPath
    );

    // Clean up the built .rbxl after upload
    await fs.unlink(rbxlPath).catch(() => {});

    // Best-effort rename to reflect current package + commit
    const placeName = await buildPlaceNameAsync(packagePath);
    await tryRenamePlaceAsync(this._placeId, placeName);
  }

  async runScriptAsync(options: RunScriptOptions): Promise<ScriptRunResult> {
    const { scriptContent, reporter, packageName, timeoutMs = 120_000 } =
      options;

    reporter.onPackagePhaseChange(packageName, 'scheduling');
    const task = await this._client.createExecutionTaskAsync(
      this._universeId,
      this._placeId,
      this._version,
      scriptContent
    );

    const completedTask = await Promise.race([
      this._client.pollTaskCompletionAsync(task.path, (state) => {
        if (state === 'PROCESSING') {
          reporter.onPackagePhaseChange(packageName, 'executing');
        }
      }),
      timeoutAsync(timeoutMs, `Test timed out after ${timeoutMs / 1000}s`),
    ]);

    this._taskPath = task.path;
    this._taskState = completedTask.state;

    return { success: completedTask.state === 'COMPLETE' };
  }

  async getLogsAsync(): Promise<string> {
    if (!this._taskPath) {
      throw new Error('No task has been run yet');
    }

    const logs = await this._client.getRawTaskLogsAsync(this._taskPath);

    if (this._taskState && this._taskState !== 'COMPLETE') {
      return [logs, `Task ended with state: ${this._taskState}`]
        .filter(Boolean)
        .join('\n');
    }

    return logs;
  }

  async cleanupAsync(): Promise<void> {
    this._taskPath = undefined;
    this._taskState = undefined;
    this._version = 0;
  }
}
