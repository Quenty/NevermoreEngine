import {
  BaseJobContext,
  type BaseJobContextOptions,
} from './base-job-context.js';
import {
  type BuiltPlace,
  type Deployment,
  type DeployPlaceOptions,
  type JobLogs,
  type RunScriptOptions,
  type ScriptJobContext,
  type ScriptRunResult,
} from './job-context.js';
import {
  type StudioScriptSession,
  type StudioSession,
  type StudioSessionFactory,
} from './studio-session.js';

export interface LocalPlaceJobContextOptions<S extends StudioSession>
  extends BaseJobContextOptions {
  studio: StudioSessionFactory<S>;
}

export class LocalDeployment<S extends StudioSession = StudioSession>
  implements Deployment
{
  readonly session: S;
  readonly builtPlace: BuiltPlace;
  cachedLogs = '';

  constructor(session: S, builtPlace: BuiltPlace) {
    this.session = session;
    this.builtPlace = builtPlace;
  }
}

/** Builds places and opens them in a local Studio, through the injected `studio`. */
export class LocalPlaceJobContext<
  S extends StudioSession = StudioSession
> extends BaseJobContext {
  private _studio: StudioSessionFactory<S>;
  private _deployments = new Set<LocalDeployment<S>>();

  constructor(options: LocalPlaceJobContextOptions<S>) {
    super(options);
    this._studio = options.studio;
  }

  async deployBuiltPlaceAsync(
    options: DeployPlaceOptions
  ): Promise<LocalDeployment<S>> {
    const { builtPlace, packageName } = options;

    const session = await this._studio.startSessionAsync({
      placePath: builtPlace.rbxlPath,
      onPhase: (phase) => {
        this._reporter.onPackagePhaseChange(packageName, phase);
      },
    });

    const deployment = new LocalDeployment(session, builtPlace);
    this._deployments.add(deployment);
    return deployment;
  }

  async releaseAsync(deployment: Deployment): Promise<void> {
    const localDeployment = deployment as LocalDeployment<S>;
    if (!this._deployments.has(localDeployment)) {
      return;
    }
    this._deployments.delete(localDeployment);

    await localDeployment.session.endAsync();
    await this.releaseBuiltPlaceAsync(localDeployment.builtPlace);
  }

  async disposeAsync(): Promise<void> {
    for (const deployment of [...this._deployments]) {
      await this.releaseAsync(deployment);
    }
    await super.disposeAsync();
  }
}

/** A local context that also runs scripts in the Studio it opened. */
export class LocalJobContext
  extends LocalPlaceJobContext<StudioScriptSession>
  implements ScriptJobContext
{
  async runScriptAsync(
    deployment: Deployment,
    options: RunScriptOptions
  ): Promise<ScriptRunResult> {
    const localDeployment = deployment as LocalDeployment<StudioScriptSession>;
    const { scriptContent, packageName, timeoutMs } = options;

    this._reporter.onPackagePhaseChange(packageName, 'executing');

    try {
      const result = await localDeployment.session.executeAsync({
        scriptContent,
        timeoutMs,
      });
      localDeployment.cachedLogs = result.logs;
      return { success: result.success, returnValues: result.returnValues };
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      localDeployment.cachedLogs = `[Studio] Error: ${errorMessage}`;
      return { success: false };
    }
  }

  async getLogsAsync(deployment: Deployment): Promise<JobLogs> {
    const localDeployment = deployment as LocalDeployment<StudioScriptSession>;

    // No severity and no fetch: the session hands over text it already has.
    // Both stay absent rather than being invented.
    return { text: localDeployment.cachedLogs, messages: [] };
  }
}
