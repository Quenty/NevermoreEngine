import * as fs from 'fs/promises';
import * as path from 'path';

export interface DeployTarget {
  universeId: number;
  placeId: number;
  project: string;
  script?: string;
}

export interface DeployConfig {
  universeId?: number;
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
      `deploy.nevermore.json not found at ${configPath}\nRun "nevermore deploy init" to create one.`
    );
  }

  const config = JSON.parse(content) as DeployConfig;

  if (!config.targets || typeof config.targets !== 'object') {
    throw new Error(`deploy.nevermore.json at ${configPath} is missing "targets" field`);
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
        `Target "${targetName}" not found in deploy.nevermore.json.`,
        `Available targets: ${availableTargets.join(', ')}`,
      ].join('\n')
    );
  }

  return target;
}

export function resolveDeployConfigPath(packagePath: string): string {
  return path.resolve(packagePath, 'deploy.nevermore.json');
}

/**
 * Walk up from startPath looking for a deploy.nevermore.json with a universeId.
 * Returns the first universeId found, or undefined.
 */
export async function discoverUniverseIdAsync(
  startPath: string
): Promise<number | undefined> {
  let current = path.resolve(startPath);

  while (true) {
    const configPath = path.join(current, 'deploy.nevermore.json');
    try {
      const content = await fs.readFile(configPath, 'utf-8');
      const config = JSON.parse(content) as Partial<DeployConfig>;

      if (typeof config.universeId === 'number') {
        return config.universeId;
      }

      // Check if any target has a universeId
      if (config.targets) {
        for (const target of Object.values(config.targets)) {
          if (typeof target.universeId === 'number') {
            return target.universeId;
          }
        }
      }
    } catch {
      // No deploy.nevermore.json here, keep walking up
    }

    const parent = path.dirname(current);
    if (parent === current) {
      break;
    }
    current = parent;
  }

  return undefined;
}
