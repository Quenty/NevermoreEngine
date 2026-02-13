import { Argv, CommandModule } from 'yargs';
import inquirer from 'inquirer';
import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../args/global-args.js';
import { DeployConfig } from '../utils/deploy-config.js';
import { buildAndUploadAsync } from '../utils/build-and-upload.js';

export interface DeployArgs extends NevermoreGlobalArgs {
  apiKey?: string;
  publish?: boolean;
  force?: boolean;
  // deploy init flags
  universeId?: number;
  placeId?: number;
  target?: string;
  project?: string;
  script?: string;
}

export class DeployCommand<T> implements CommandModule<T, DeployArgs> {
  public command = 'deploy <subcommand>';
  public describe = 'Build and upload a place via Roblox Open Cloud';

  public builder = (args: Argv<T>) => {
    args.command(
      'init',
      'Create a deploy.json for the current package',
      (yargs) => {
        return yargs
          .option('universe-id', {
            describe: 'Roblox universe ID',
            type: 'number',
          })
          .option('place-id', {
            describe: 'Roblox place ID',
            type: 'number',
          })
          .option('target', {
            describe: 'Deploy target name',
            type: 'string',
            default: 'test',
          })
          .option('project', {
            describe: 'Rojo project file (relative to package)',
            type: 'string',
          })
          .option('script', {
            describe:
              'Luau script to execute after deploy (relative to package)',
            type: 'string',
          })
          .option('force', {
            describe: 'Overwrite existing deploy.json',
            type: 'boolean',
            default: false,
          });
      },
      async (initArgs) => {
        try {
          await DeployCommand._handleInitAsync(
            initArgs as unknown as DeployArgs
          );
        } catch (err) {
          OutputHelper.error(err instanceof Error ? err.message : String(err));
          process.exit(1);
        }
      }
    );

    args.command(
      ['run [target]', '$0 [target]'],
      'Deploy a target from deploy.json',
      (yargs) => {
        return yargs
          .positional('target', {
            describe: 'Deploy target name from deploy.json',
            type: 'string',
            default: 'test',
          })
          .option('api-key', {
            describe: 'Roblox Open Cloud API key',
            type: 'string',
          })
          .option('publish', {
            describe: 'Publish the place (default: Saved)',
            type: 'boolean',
            default: false,
          })
          .option('universe-id', {
            describe: 'Override universe ID from deploy.json',
            type: 'number',
          })
          .option('place-id', {
            describe: 'Override place ID from deploy.json',
            type: 'number',
          });
      },
      async (runArgs) => {
        try {
          await DeployCommand._handleRunAsync(
            runArgs as unknown as DeployArgs
          );
        } catch (err) {
          OutputHelper.error(err instanceof Error ? err.message : String(err));
          process.exit(1);
        }
      }
    );

    return args as Argv<DeployArgs>;
  };

  public handler = async () => {};

  private static async _handleRunAsync(args: DeployArgs): Promise<void> {
    const targetName = args.target ?? 'test';

    const result = await buildAndUploadAsync(args, targetName, args.publish ? 'publish.rbxl' : 'deploy.rbxl');
    if (!result) {
      OutputHelper.info(
        `[DRYRUN] Would build and upload`
      );
      return;
    }

    if (args.publish) {
      OutputHelper.info(`Published v${result.version} — live in game.`);
    } else {
      OutputHelper.info(`Saved v${result.version} — not yet live.`);
      OutputHelper.hint('Use --publish to make it live in game.');
    }
  }

  private static async _handleInitAsync(args: DeployArgs): Promise<void> {
    const packagePath = process.cwd();
    const deployJsonPath = path.join(packagePath, 'deploy.json');

    if (await _fileExistsAsync(deployJsonPath) && !args.force) {
      OutputHelper.warn(`deploy.json already exists at ${deployJsonPath}`);
      OutputHelper.hint('Use --force to overwrite, or edit it manually.');
      return;
    }

    if (
      !(await _fileExistsAsync(path.join(packagePath, 'package.json')))
    ) {
      throw new Error(
        'No package.json found — are you in a package directory?'
      );
    }

    const packageName = path.basename(packagePath);
    OutputHelper.info(`Setting up deploy.json for ${packageName}`);

    const detectedProject = await _detectProjectFileAsync(packagePath);
    const detectedScript = await _detectScriptFileAsync(packagePath);

    if (detectedProject) {
      OutputHelper.info(`Detected rojo project: ${detectedProject}`);
    }
    if (detectedScript) {
      OutputHelper.info(`Detected test script: ${detectedScript}`);
    }

    let targetName = args.target ?? 'test';
    let universeId = args.universeId;
    let placeId = args.placeId;
    let project = args.project ?? detectedProject;
    let script = args.script ?? detectedScript;

    const needsPrompt = !universeId || !placeId || !project;

    if (needsPrompt && args.yes) {
      const missing: string[] = [];
      if (!universeId) missing.push('--universe-id');
      if (!placeId) missing.push('--place-id');
      if (!project) missing.push('--project');
      throw new Error(
        `Missing required flags for non-interactive mode: ${missing.join(', ')}`
      );
    }

    if (needsPrompt) {
      // Step 1: target name + universe ID
      const basicAnswers = await inquirer.prompt([
        {
          type: 'input',
          name: 'targetName',
          message: 'Target name:',
          default: targetName,
          when: () => !args.target,
        },
        {
          type: 'number',
          name: 'universeId',
          message:
            'Universe ID (find at https://create.roblox.com/dashboard/creations):',
          when: () => !universeId,
          validate: (input: number) =>
            Number.isInteger(input) && input > 0
              ? true
              : 'Must be a positive integer',
        },
      ]);

      targetName = basicAnswers.targetName ?? targetName;
      universeId = basicAnswers.universeId ?? universeId;

      // Step 2: place ID — try to list places from the universe
      if (!placeId && universeId) {
        placeId = await _promptPlaceIdAsync(universeId);
      }

      // Step 3: project + script
      const fileAnswers = await inquirer.prompt([
        {
          type: 'input',
          name: 'project',
          message: 'Rojo project file (relative to package):',
          default: project ?? 'test/default.project.json',
          when: () => !project,
          validate: async (input: string) => {
            const fullPath = path.resolve(packagePath, input);
            if (await _fileExistsAsync(fullPath)) {
              return true;
            }
            return `File not found: ${fullPath}`;
          },
        },
        {
          type: 'confirm',
          name: 'hasScript',
          message: script
            ? `Run ${script} via Open Cloud after upload? (smoke test)`
            : 'Run a Luau script after upload? (e.g. a smoke test that boots the place via Open Cloud)',
          default: !!script,
          when: () => !args.script,
        },
        {
          type: 'input',
          name: 'script',
          message: 'Script file (relative to package):',
          default:
            script ?? 'test/scripts/Server/ServerMain.server.lua',
          when: (answers: { hasScript?: boolean }) =>
            !args.script && answers.hasScript && !script,
          validate: async (input: string) => {
            const fullPath = path.resolve(packagePath, input);
            if (await _fileExistsAsync(fullPath)) {
              return true;
            }
            return `File not found: ${fullPath}`;
          },
        },
      ]);

      project = fileAnswers.project ?? project;
      if (fileAnswers.hasScript === false) {
        script = undefined;
      } else if (fileAnswers.script) {
        script = fileAnswers.script;
      }
    }

    const config: DeployConfig = {
      targets: {
        [targetName]: {
          universeId: universeId!,
          placeId: placeId!,
          project: project!,
          ...(script ? { script } : {}),
        },
      },
    };

    const configJson = JSON.stringify(config, null, 2);

    if (args.dryrun) {
      OutputHelper.info('[DRYRUN]: Would write deploy.json:');
      console.log(configJson);
      return;
    }

    console.log(configJson);
    if (!args.yes) {
      const { confirm } = await inquirer.prompt([
        {
          type: 'confirm',
          name: 'confirm',
          message: `Write deploy.json to ${packageName}?`,
          default: true,
        },
      ]);
      if (!confirm) {
        OutputHelper.info('Aborted.');
        return;
      }
    }

    await fs.writeFile(deployJsonPath, configJson + '\n');
    OutputHelper.info(`Created ${deployJsonPath}`);
  }
}

interface RobloxPlace {
  id: number;
  universeId: number;
  name: string;
  description: string;
}

async function _listPlacesAsync(
  universeId: number
): Promise<RobloxPlace[]> {
  const places: RobloxPlace[] = [];
  let cursor: string | undefined;

  while (true) {
    const url = new URL(
      `https://develop.roblox.com/v1/universes/${universeId}/places`
    );
    url.searchParams.set('limit', '100');
    if (cursor) {
      url.searchParams.set('cursor', cursor);
    }

    const response = await fetch(url.toString());
    if (!response.ok) {
      throw new Error(
        `Failed to list places for universe ${universeId}: ${response.status}`
      );
    }

    const data = (await response.json()) as {
      data: RobloxPlace[];
      nextPageCursor: string | null;
    };

    places.push(...data.data);

    if (!data.nextPageCursor) {
      break;
    }
    cursor = data.nextPageCursor;
  }

  return places;
}

async function _promptPlaceIdAsync(universeId: number): Promise<number> {
  try {
    OutputHelper.info(`Fetching places for universe ${universeId}...`);
    const places = await _listPlacesAsync(universeId);

    if (places.length === 1) {
      OutputHelper.info(
        `Found place: ${places[0].name} (${places[0].id})`
      );
      return places[0].id;
    } else if (places.length > 1) {
      const choices = places.map((p) => ({
        name: `${p.name} (${p.id})`,
        value: p.id,
      }));
      const { selectedPlaceId } = await inquirer.prompt([
        {
          type: 'list',
          name: 'selectedPlaceId',
          message: 'Select a place:',
          choices,
        },
      ]);
      return selectedPlaceId;
    }
  } catch (err) {
    OutputHelper.warn(
      `Could not fetch places (universe may be private or not exist).`
    );
  }

  const { manualPlaceId } = await inquirer.prompt([
    {
      type: 'number',
      name: 'manualPlaceId',
      message: 'Place ID:',
      validate: (input: number) =>
        Number.isInteger(input) && input > 0
          ? true
          : 'Must be a positive integer',
    },
  ]);
  return manualPlaceId;
}

async function _fileExistsAsync(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function _detectProjectFileAsync(
  packagePath: string
): Promise<string | undefined> {
  const candidate = path.join(packagePath, 'test', 'default.project.json');
  if (await _fileExistsAsync(candidate)) {
    return 'test/default.project.json';
  }
  return undefined;
}

async function _detectScriptFileAsync(
  packagePath: string
): Promise<string | undefined> {
  const candidates = [
    'test/scripts/Server/ServerMain.server.lua',
    'test/scripts/Server/ServerMain.server.luau',
  ];
  for (const candidate of candidates) {
    if (await _fileExistsAsync(path.join(packagePath, candidate))) {
      return candidate;
    }
  }
  return undefined;
}

