import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { StudioBridge } from '@quenty/studio-bridge';
import {
  type BuiltPlace,
  type Deployment,
  type DeployPlaceOptions,
  type RunScriptOptions,
  type ScriptRunResult,
} from './job-context.js';
import { BaseJobContext } from './base-job-context.js';

class LocalDeployment implements Deployment {
  bridge: StudioBridge;
  builtPlace: BuiltPlace;
  cachedLogs = '';

  constructor(bridge: StudioBridge, builtPlace: BuiltPlace) {
    this.bridge = bridge;
    this.builtPlace = builtPlace;
  }
}

export class LocalJobContext extends BaseJobContext {
  private _deployments = new Set<LocalDeployment>();

  async deployBuiltPlaceAsync(
    reporter: Reporter,
    options: DeployPlaceOptions
  ): Promise<Deployment> {
    const { builtPlace, packageName } = options;

    const bridge = new StudioBridge({
      placePath: builtPlace.rbxlPath,
      onPhase: (phase) => {
        if (phase === 'launching' || phase === 'connecting') {
          reporter.onPackagePhaseChange(packageName, phase);
        }
      },
    });

    await bridge.startAsync();

    const deployment = new LocalDeployment(bridge, builtPlace);
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

    // Release build artifacts (removes .rbxl, .rbxl.lock, and temp dir)
    await this.releaseBuiltPlaceAsync(localDeployment.builtPlace);

    this._deployments.delete(localDeployment);
  }

  async disposeAsync(): Promise<void> {
    const remaining = [...this._deployments];
    for (const d of remaining) {
      await this.releaseAsync(d);
    }
    await super.disposeAsync();
  }
}
