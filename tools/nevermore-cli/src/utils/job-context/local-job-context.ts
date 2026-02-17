import * as fs from 'fs/promises';
import { StudioBridge } from '@quenty/studio-bridge';
import {
  type JobContext,
  type DeployPlaceOptions,
  type RunScriptOptions,
  type ScriptRunResult,
} from './job-context.js';

export class LocalJobContext implements JobContext {
  private _bridge: StudioBridge | undefined;
  private _cachedLogs = '';
  private _rbxlPath: string | undefined;

  async deployBuiltPlaceAsync(options: DeployPlaceOptions): Promise<void> {
    const { rbxlPath, reporter, packageName } = options;

    this._rbxlPath = rbxlPath;
    this._bridge = new StudioBridge({
      placePath: rbxlPath,
      onPhase: (phase) => {
        if (phase === 'launching' || phase === 'connecting') {
          reporter.onPackagePhaseChange(packageName, phase);
        }
      },
    });

    await this._bridge.startAsync();
  }

  async runScriptAsync(options: RunScriptOptions): Promise<ScriptRunResult> {
    const { scriptContent, reporter, packageName, timeoutMs } = options;

    if (!this._bridge) {
      throw new Error('No bridge — call deployBuiltPlaceAsync first');
    }

    reporter.onPackagePhaseChange(packageName, 'executing');

    try {
      const result = await this._bridge.executeAsync({
        scriptContent,
        timeoutMs,
      });
      this._cachedLogs = result.logs;
      return { success: result.success };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      this._cachedLogs = `[StudioBridge] Error: ${errorMessage}`;
      return { success: false };
    }
  }

  async getLogsAsync(): Promise<string> {
    return this._cachedLogs;
  }

  async cleanupAsync(): Promise<void> {
    if (this._bridge) {
      await this._bridge.stopAsync();
      this._bridge = undefined;
    }

    if (this._rbxlPath) {
      await Promise.all([
        fs.unlink(this._rbxlPath).catch(() => {}),
        fs.unlink(`${this._rbxlPath}.lock`).catch(() => {}),
      ]);
      this._rbxlPath = undefined;
    }

    this._cachedLogs = '';
  }
}
