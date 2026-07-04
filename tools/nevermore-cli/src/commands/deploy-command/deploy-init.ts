import inquirer from 'inquirer';
import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  DeployConfig,
  discoverUniverseIdAsync,
} from '../../utils/build/deploy-config.js';
import {
  getRobloxCookieAsync,
  createPlaceInUniverseAsync,
  findGitRepoRootAsync,
} from '@quenty/nevermore-cli-helpers';
import {
  fileExistsAsync,
  buildPlaceNameAsync,
} from '../../utils/nevermore-cli-utils.js';
import { DeployArgs } from './index.js';
import { promptPlaceIdAsync } from './deploy-init-prompts.js';
import {
  detectProjectFileAsync,
  detectScriptFileAsync,
  detectTargetNameAsync,
} from './deploy-init-utils.js';

interface InitState {
  packagePath: string;
  packageName: string;
  placeName: string;
  targetName: string;
  universeId?: number;
  placeId?: number;
  project?: string;
  scriptTemplate?: string;
  mode: 'auto' | 'interactive' | 'non-interactive';
}

export async function handleInitAsync(args: DeployArgs): Promise<void> {
  const packagePath = process.cwd();
  const deployJsonPath = path.join(packagePath, 'deploy.nevermore.json');

  if ((await fileExistsAsync(deployJsonPath)) && !args.force) {
    OutputHelper.warn(
      `deploy.nevermore.json already exists at ${deployJsonPath}`
    );
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
    await resolveInteractiveAsync(args, state);
  }

  await writeConfig(args, state, deployJsonPath);
}

async function detectDefaults(
  args: DeployArgs,
  packagePath: string
): Promise<InitState> {
  const packageName = path.basename(packagePath);
  const placeName = await buildPlaceNameAsync(packagePath);

  const detectedProject = await detectProjectFileAsync(packagePath);
  const detectedScript = await detectScriptFileAsync(packagePath);
  const detectedTarget = await detectTargetNameAsync(packagePath);

  let universeId = args.universeId;
  if (!universeId) {
    const discovered = await discoverUniverseIdAsync(packagePath);
    if (discovered) {
      universeId = discovered;
    }
  }

  return {
    packagePath,
    packageName,
    placeName,
    targetName: args.target ?? detectedTarget,
    universeId,
    placeId: args.placeId,
    project: args.project ?? detectedProject,
    scriptTemplate: args.scriptTemplate ?? detectedScript,
    mode: args.yes ? 'non-interactive' : 'interactive',
  };
}

async function resolveNonInteractive(
  args: DeployArgs,
  state: InitState
): Promise<void> {
  const missing: string[] = [];
  if (!state.universeId) missing.push('--universe-id');
  if (!state.project) missing.push('--project');
  if (isTestTarget(state) && !state.scriptTemplate) {
    missing.push('--script-template');
  }
  if (missing.length > 0) {
    throw new Error(
      `Missing required flags for non-interactive mode: ${missing.join(', ')}`
    );
  }

  if (args.createPlace && state.universeId && !state.placeId) {
    const cookie = await getRobloxCookieAsync();
    state.placeId = await createPlaceInUniverseAsync(
      cookie,
      state.universeId,
      state.placeName
    );
  }

  if (!state.placeId) {
    throw new Error(
      'Missing required flag for non-interactive mode: --place-id (or use --create-place)'
    );
  }
}

async function resolveInteractiveAsync(
  args: DeployArgs,
  state: InitState
): Promise<void> {
  await promptModeAsync(state);
  await ensureUniverseIdAsync(args, state); // Resolves targetName before script prompt
  await ensureProjectAndScriptAsync(args, state);
  await ensurePromptPlaceIdAsync(state); // This modifies the cloud, so is last
}

function isTestTarget(state: InitState): boolean {
  return state.targetName === 'test';
}

async function promptModeAsync(state: InitState): Promise<void> {
  const repoRoot = await findGitRepoRootAsync(state.packagePath);
  const deployJsonPath = path.join(state.packagePath, 'deploy.nevermore.json');
  const displayPath = repoRoot
    ? path.relative(repoRoot, deployJsonPath).replace(/\\/g, '/')
    : `${state.packageName}/deploy.nevermore.json`;

  const autoPreview = buildAutoPreview(state);

  const { mode } = await inquirer.prompt([
    {
      type: 'select',
      name: 'mode',
      message: `How would you like to set up ${displayPath}?`,
      choices: [
        {
          name: `Automatically set up as '${state.targetName}' target`,
          value: 'auto',
          description: `\nPreview:\n${autoPreview}`,
        },
        {
          name: 'Manually configure each field',
          value: 'interactive',
          description: '\nWalk through prompts for each field.',
        },
      ],
    },
  ]);

  state.mode = mode;
}

function buildAutoPreview(state: InitState): string {
  const projectDefault = 'test/default.project.json';
  const scriptDefault = 'test/scripts/Server/ServerMain.server.lua';

  const target: Record<string, unknown> = {
    universeId: state.universeId ?? '<prompted>',
    placeId: '<auto-created>',
    project:
      state.project ?? `<prompted — ${projectDefault} not found, create it>`,
  };
  if (state.scriptTemplate) {
    target.scriptTemplate = state.scriptTemplate;
  } else if (isTestTarget(state)) {
    target.scriptTemplate = `<prompted — ${scriptDefault} not found, create it>`;
  }

  return JSON.stringify({ targets: { [state.targetName]: target } }, null, 2);
}

async function ensureUniverseIdAsync(
  args: DeployArgs,
  state: InitState
): Promise<void> {
  const answers = await inquirer.prompt([
    {
      type: 'select',
      name: 'targetName',
      message: 'Target name:',
      default: state.targetName,
      choices: [
        {
          name: 'test — unit-test place with a script template',
          value: 'test',
        },
        {
          name: 'integration — integration game / place without a test script',
          value: 'integration',
        },
      ],
      when: () => !args.target && state.mode !== 'auto',
    },
    {
      type: 'number',
      name: 'universeId',
      message:
        'Universe ID (find at https://create.roblox.com/dashboard/creations):',
      default: state.universeId,
      when: () =>
        !args.universeId && (state.mode === 'interactive' || !state.universeId),
      validate: (input: number) =>
        Number.isInteger(input) && input > 0
          ? true
          : 'Must be a positive integer',
    },
  ]);

  state.targetName = answers.targetName ?? state.targetName;
  state.universeId = answers.universeId ?? state.universeId;
}

async function ensurePromptPlaceIdAsync(state: InitState): Promise<void> {
  if (!state.universeId) {
    throw new Error('Universe ID is required to set up place ID');
  }

  try {
    const cookie = await getRobloxCookieAsync();
    state.placeId = await createPlaceInUniverseAsync(
      cookie,
      state.universeId,
      state.placeName
    );
  } catch (err) {
    OutputHelper.warn(
      `Failed to auto-create place in universe ${state.universeId}: ${
        err instanceof Error ? err.message : String(err)
      }`
    );

    state.placeId = await promptPlaceIdAsync(state.universeId, state.placeName);
  }
}

async function ensureProjectAndScriptAsync(
  args: DeployArgs,
  state: InitState
): Promise<void> {
  const scriptRequired = isTestTarget(state);
  const needsScript = !state.scriptTemplate && !args.scriptTemplate;

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
      message: 'Include a Luau testing script?',
      default: false,
      when: () => needsScript && state.mode !== 'auto' && !scriptRequired,
    },
    {
      type: 'input',
      name: 'scriptTemplate',
      message: scriptRequired
        ? 'Script template file for test target (required, relative to package):'
        : 'Script template file (relative to package):',
      default: 'test/scripts/Server/ServerMain.server.lua',
      when: (promptAnswers: { hasScript?: boolean }) =>
        needsScript &&
        (scriptRequired ||
          (state.mode !== 'auto' && !!promptAnswers.hasScript)),
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
  if (answers.scriptTemplate) {
    state.scriptTemplate = answers.scriptTemplate;
  }
}

async function writeConfig(
  args: DeployArgs,
  state: InitState,
  deployJsonPath: string
): Promise<void> {
  const config: DeployConfig = {
    targets: {
      [state.targetName]: {
        universeId: state.universeId!,
        placeId: state.placeId!,
        project: state.project!.replace(/\\/g, '/'),
        ...(state.scriptTemplate
          ? { scriptTemplate: state.scriptTemplate.replace(/\\/g, '/') }
          : {}),
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
  await fs.writeFile(deployJsonPath, configJson + '\n');
  OutputHelper.info(`Created ${deployJsonPath}`);
}
