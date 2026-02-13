import * as fs from 'fs/promises';
import * as path from 'path';

export interface DeployTarget {
  universeId: number;
  placeId: number;
  project: string;
  script?: string;
}

export interface DeployConfig {
  targets: Record<string, DeployTarget>;
}

export async function loadDeployConfigAsync(
  configPath: string
): Promise<DeployConfig> {
  let content: string;
  try {
    content = await fs.readFile(configPath, 'utf-8');
  } catch {
    throw new Error(
      `deploy.json not found at ${configPath}\nRun "nevermore deploy init" to create one.`
    );
  }

  const config = JSON.parse(content) as DeployConfig;

  if (!config.targets || typeof config.targets !== 'object') {
    throw new Error(`deploy.json at ${configPath} is missing "targets" field`);
  }

  for (const [name, target] of Object.entries(config.targets)) {
    if (typeof target.universeId !== 'number') {
      throw new Error(
        `Target "${name}" is missing or has invalid "universeId"`
      );
    }
    if (typeof target.placeId !== 'number') {
      throw new Error(`Target "${name}" is missing or has invalid "placeId"`);
    }
    if (typeof target.project !== 'string') {
      throw new Error(`Target "${name}" is missing or has invalid "project"`);
    }
  }

  return config;
}

export function resolveTarget(
  config: DeployConfig,
  targetName: string
): DeployTarget {
  const availableTargets = Object.keys(config.targets);
  const target = config.targets[targetName];

  if (!target) {
    throw new Error(
      [
        `Target "${targetName}" not found in deploy.json.`,
        `Available targets: ${availableTargets.join(', ')}`,
      ].join('\n')
    );
  }

  return target;
}

export function resolveDeployConfigPath(packagePath: string): string {
  return path.resolve(packagePath, 'deploy.json');
}
