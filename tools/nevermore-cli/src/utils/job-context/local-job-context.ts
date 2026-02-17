import * as fs from 'fs/promises';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { StudioBridge } from '@quenty/studio-bridge';
import {
  type Deployment,
  type JobContext,
  type DeployPlaceOptions,
  type RunScriptOptions,
  type ScriptRunResult,
} from './job-context.js';

class LocalDeployment implements Deployment {
  bridge: StudioBridge;
  rbxlPath: string;
  cachedLogs = '';

  constructor(bridge: StudioBridge, rbxlPath: string) {
    this.bridge = bridge;
    this.rbxlPath = rbxlPath;
  }
}

export class LocalJobContext implements JobContext {
  private _deployments = new Set<LocalDeployment>();

  async deployBuiltPlaceAsync(
    reporter: Reporter,
    options: DeployPlaceOptions
  ): Promise<Deployment> {
    const { rbxlPath, packageName } = options;

    const bridge = new StudioBridge({
      placePath: rbxlPath,
      onPhase: (phase) => {
        if (phase === 'launching' || phase === 'connecting') {
          reporter.onPackagePhaseChange(packageName, phase);
        }
      },
    });

    await bridge.startAsync();

    const deployment = new LocalDeployment(bridge, rbxlPath);
    this._deployments.add(deployment);
    return deployment;
  }

  async runScriptAsync(
    deployment: Deployment,
    reporter: Reporter,
    options: RunScriptOptions
  ): Promise<ScriptRunResult> {
    const localDeployment = deployment as LocalDeployment;
    const { scriptContent, packageName, timeoutMs } = options;

    reporter.onPackagePhaseChange(packageName, 'executing');

    try {
      const result = await localDeployment.bridge.executeAsync({
        scriptContent,
        timeoutMs,
      });
      localDeployment.cachedLogs = result.logs;
      return { success: result.success };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      localDeployment.cachedLogs = `[StudioBridge] Error: ${errorMessage}`;
      return { success: false };
    }
  }

  async getLogsAsync(deployment: Deployment): Promise<string> {
    const localDeployment = deployment as LocalDeployment;
    return localDeployment.cachedLogs;
  }

  async releaseAsync(deployment: Deployment): Promise<void> {
    const localDeployment = deployment as LocalDeployment;

    await localDeployment.bridge.stopAsync();

    await Promise.all([
      fs.unlink(localDeployment.rbxlPath).catch(() => {}),
      fs.unlink(`${localDeployment.rbxlPath}.lock`).catch(() => {}),
    ]);

    this._deployments.delete(localDeployment);
  }

  async disposeAsync(): Promise<void> {
    const remaining = [...this._deployments];
    for (const d of remaining) {
      await this.releaseAsync(d);
    }
  }
}
