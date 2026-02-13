import inquirer from 'inquirer';
import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { DeployConfig, discoverUniverseIdAsync } from '../../utils/deploy-config.js';
import { getRobloxCookieAsync, createPlaceInUniverseAsync } from '../../utils/roblox-auth/index.js';
import { fileExistsAsync, buildPlaceNameAsync } from '../../utils/nevermore-cli-utils.js';
import { DeployArgs } from './index.js';
import { promptPlaceIdAsync } from './deploy-init-prompts.js';
import { detectProjectFileAsync, detectScriptFileAsync } from './deploy-init-utils.js';

interface InitState {
  packagePath: string;
  packageName: string;
  placeName: string;
  targetName: string;
  universeId?: number;
  placeId?: number;
  project?: string;
  script?: string;
}

export async function handleInitAsync(args: DeployArgs): Promise<void> {
  const packagePath = process.cwd();
  const deployJsonPath = path.join(packagePath, 'deploy.nevermore.json');

  if (await fileExistsAsync(deployJsonPath) && !args.force) {
    OutputHelper.warn(`deploy.nevermore.json already exists at ${deployJsonPath}`);
    OutputHelper.hint('Use --force to overwrite, or edit it manually.');
    return;
  }

  if (!(await fileExistsAsync(path.join(packagePath, 'package.json')))) {
    throw new Error('No package.json found — are you in a package directory?');
  }

  const state = await detectDefaults(args, packagePath);

  if (args.yes) {
    await resolveNonInteractive(args, state);
  } else {
    await resolveInteractive(args, state);
  }

  await writeConfig(args, state, deployJsonPath);
}

async function detectDefaults(args: DeployArgs, packagePath: string): Promise<InitState> {
  const packageName = path.basename(packagePath);
  const placeName = await buildPlaceNameAsync(packagePath);

  OutputHelper.info(`Setting up deploy.nevermore.json for ${packageName}`);

  const detectedProject = await detectProjectFileAsync(packagePath);
  const detectedScript = await detectScriptFileAsync(packagePath);

  if (detectedProject) {
    OutputHelper.info(`Detected rojo project: ${detectedProject}`);
  }
  if (detectedScript) {
    OutputHelper.info(`Detected test script: ${detectedScript}`);
  }

  let universeId = args.universeId;
  if (!universeId) {
    const discovered = await discoverUniverseIdAsync(packagePath);
    if (discovered) {
      OutputHelper.info(`Discovered universe ID ${discovered} from parent deploy.nevermore.json`);
      universeId = discovered;
    }
  }

  return {
    packagePath,
    packageName,
    placeName,
    targetName: args.target ?? 'test',
    universeId,
    placeId: args.placeId,
    project: args.project ?? detectedProject,
    script: args.script ?? detectedScript,
  };
}

async function resolveNonInteractive(args: DeployArgs, state: InitState): Promise<void> {
  const missing: string[] = [];
  if (!state.universeId) missing.push('--universe-id');
  if (!state.project) missing.push('--project');
  if (missing.length > 0) {
    throw new Error(
      `Missing required flags for non-interactive mode: ${missing.join(', ')}`
    );
  }

  if (args.createPlace && state.universeId && !state.placeId) {
    const cookie = await getRobloxCookieAsync();
    state.placeId = await createPlaceInUniverseAsync(cookie, state.universeId, state.placeName);
  }

  if (!state.placeId) {
    throw new Error(
      'Missing required flag for non-interactive mode: --place-id (or use --create-place)'
    );
  }
}

async function resolveInteractive(args: DeployArgs, state: InitState): Promise<void> {
  if (state.universeId && state.placeId && state.project) {
    return;
  }

  if (await tryAutoSetup(state)) {
    return;
  }

  await promptUniverseId(args, state);
  await promptPlaceId(state);
  await promptProjectAndScript(args, state);
}

async function tryAutoSetup(state: InitState): Promise<boolean> {
  if (!state.universeId || !state.project || state.placeId) {
    return false;
  }

  const { mode } = await inquirer.prompt([
    {
      type: 'select',
      name: 'mode',
      message: 'How would you like to set up?',
      choices: [
        {
          name: `Setup automatically (creates a new place in universe ${state.universeId})`,
          value: 'auto',
        },
        {
          name: 'Configure manually',
          value: 'manual',
        },
      ],
    },
  ]);

  if (mode !== 'auto') {
    return false;
  }

  const cookie = await getRobloxCookieAsync();
  state.placeId = await createPlaceInUniverseAsync(cookie, state.universeId, state.placeName);
  return true;
}

async function promptUniverseId(args: DeployArgs, state: InitState): Promise<void> {
  const answers = await inquirer.prompt([
    {
      type: 'input',
      name: 'targetName',
      message: 'Target name:',
      default: state.targetName,
      when: () => !args.target,
    },
    {
      type: 'number',
      name: 'universeId',
      message: 'Universe ID (find at https://create.roblox.com/dashboard/creations):',
      when: () => !state.universeId,
      validate: (input: number) =>
        Number.isInteger(input) && input > 0 ? true : 'Must be a positive integer',
    },
  ]);

  state.targetName = answers.targetName ?? state.targetName;
  state.universeId = answers.universeId ?? state.universeId;
}

async function promptPlaceId(state: InitState): Promise<void> {
  if (state.placeId || !state.universeId) {
    return;
  }

  state.placeId = await promptPlaceIdAsync(state.universeId, state.placeName);
}

async function promptProjectAndScript(args: DeployArgs, state: InitState): Promise<void> {
  const answers = await inquirer.prompt([
    {
      type: 'input',
      name: 'project',
      message: 'Rojo project file (relative to package):',
      default: state.project ?? 'test/default.project.json',
      when: () => !state.project,
      validate: async (input: string) => {
        const fullPath = path.resolve(state.packagePath, input);
        if (await fileExistsAsync(fullPath)) {
          return true;
        }
        return `File not found: ${fullPath}`;
      },
    },
    {
      type: 'confirm',
      name: 'hasScript',
      message: state.script
        ? `Run ${state.script} via Open Cloud after upload? (smoke test)`
        : 'Run a Luau script after upload? (e.g. a smoke test that boots the place via Open Cloud)',
      default: !!state.script,
      when: () => !args.script,
    },
    {
      type: 'input',
      name: 'script',
      message: 'Script file (relative to package):',
      default: state.script ?? 'test/scripts/Server/ServerMain.server.lua',
      when: (promptAnswers: { hasScript?: boolean }) =>
        !args.script && promptAnswers.hasScript && !state.script,
      validate: async (input: string) => {
        const fullPath = path.resolve(state.packagePath, input);
        if (await fileExistsAsync(fullPath)) {
          return true;
        }
        return `File not found: ${fullPath}`;
      },
    },
  ]);

  state.project = answers.project ?? state.project;
  if (answers.hasScript === false) {
    state.script = undefined;
  } else if (answers.script) {
    state.script = answers.script;
  }
}

async function writeConfig(args: DeployArgs, state: InitState, deployJsonPath: string): Promise<void> {
  const config: DeployConfig = {
    targets: {
      [state.targetName]: {
        universeId: state.universeId!,
        placeId: state.placeId!,
        project: state.project!,
        ...(state.script ? { script: state.script } : {}),
      },
    },
  };

  const configJson = JSON.stringify(config, null, 2);

  if (args.dryrun) {
    OutputHelper.info('[DRYRUN]: Would write deploy.nevermore.json:');
    console.log(configJson);
    return;
  }

  console.log(configJson);
  if (!args.yes) {
    const { confirm } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: `Write deploy.nevermore.json to ${state.packageName}?`,
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
