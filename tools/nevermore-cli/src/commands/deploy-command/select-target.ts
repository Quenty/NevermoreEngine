import inquirer from 'inquirer';
import {
  type DeployConfig,
  loadDeployConfigAsync,
  resolveDefaultTargetName,
  resolveDeployConfigPath,
} from '../../utils/build/deploy-config.js';

export interface SelectTargetOptions {
  explicitTarget?: string;
  publish: boolean;
}

export interface SelectTargetResult {
  targetName: string;
  autoDetected: boolean;
}

export async function selectTargetAsync(
  cwd: string,
  options: SelectTargetOptions
): Promise<SelectTargetResult> {
  if (options.explicitTarget) {
    return { targetName: options.explicitTarget, autoDetected: false };
  }

  const config = await loadDeployConfigAsync(resolveDeployConfigPath(cwd));
  const targets = Object.keys(config.targets);

  if (targets.length <= 1 || !_canPrompt()) {
    return {
      targetName: resolveDefaultTargetName(config),
      autoDetected: true,
    };
  }

  const targetName = await _promptForTargetAsync(config, options.publish);
  return { targetName, autoDetected: false };
}

function _canPrompt(): boolean {
  return Boolean(process.stdin.isTTY && process.stdout.isTTY);
}

async function _promptForTargetAsync(
  config: DeployConfig,
  publish: boolean
): Promise<string> {
  const targets = Object.keys(config.targets);
  const preferred = _preferredTarget(targets);
  const orderedTargets = preferred
    ? [preferred, ...targets.filter((t) => t !== preferred)]
    : targets;

  const choices = orderedTargets.map((name) => {
    const target = config.targets[name]!;
    return {
      name: `${name} (place ${target.placeId})`,
      value: name,
    };
  });

  const action = publish ? 'publish' : 'deploy';
  const { selection } = await inquirer.prompt<{ selection: string }>([
    {
      type: 'select',
      name: 'selection',
      message: `Select a target to ${action} to:`,
      choices,
      default: preferred,
    },
  ]);
  return selection;
}

function _preferredTarget(targets: string[]): string | undefined {
  if (targets.includes('integration')) return 'integration';
  if (targets.includes('test')) return 'test';
  return undefined;
}
