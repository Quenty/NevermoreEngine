import { Argv, CommandModule } from 'yargs';
import inquirer from 'inquirer';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../args/global-args.js';
import {
  saveApiKeyAsync,
  loadStoredApiKeyAsync,
  clearApiKeyAsync,
  validateApiKeyAsync,
  printApiKeySetupHelp,
} from '../utils/credential-store.js';

export interface LoginArgs extends NevermoreGlobalArgs {
  apiKey?: string;
  clear?: boolean;
  status?: boolean;
  force?: boolean;
}

export class LoginCommand<T> implements CommandModule<T, LoginArgs> {
  public command = 'login';
  public describe = 'Store a Roblox Open Cloud API key for deploy and test';

  public builder = (args: Argv<T>) => {
    args.option('api-key', {
      describe: 'API key to store (prompts interactively if omitted)',
      type: 'string',
    });

    args.option('clear', {
      describe: 'Remove stored credentials',
      type: 'boolean',
      default: false,
    });

    args.option('status', {
      describe: 'Show current credential status',
      type: 'boolean',
      default: false,
    });

    args.option('force', {
      describe: 'Replace existing credentials',
      type: 'boolean',
      default: false,
    });

    return args as Argv<LoginArgs>;
  };

  public handler = async (args: LoginArgs) => {
    try {
      await this._handleAsync(args);
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  };

  private _handleAsync = async (args: LoginArgs) => {
    if (args.clear) {
      const existing = await loadStoredApiKeyAsync();
      if (!existing) {
        OutputHelper.info('No stored credentials to clear.');
      } else {
        await clearApiKeyAsync();
        OutputHelper.info('Stored credentials cleared.');
      }
      return;
    }

    if (args.status) {
      await this._showStatusAsync(args);
      return;
    }

    if (!args.force && !args.apiKey) {
      const existingSource = await this._findExistingKeySourceAsync();
      if (existingSource) {
        OutputHelper.info(`Already logged in (via ${existingSource}).`);
        OutputHelper.hint('Use "nevermore login --force" to replace credentials.');
        return;
      }
    }

    let apiKey = args.apiKey;
    if (!apiKey) {
      if (args.yes) {
        throw new Error(
          'Cannot prompt for API key in non-interactive mode. Pass --api-key.'
        );
      }

      printApiKeySetupHelp();

      const { promptedKey } = await inquirer.prompt([
        {
          type: 'password',
          name: 'promptedKey',
          message: 'Enter your Roblox Open Cloud API key:',
          mask: '*',
          validate: (input: string) =>
            input.length > 0 || 'API key cannot be empty',
        },
      ]);
      apiKey = promptedKey;
    }

    OutputHelper.info('Validating API key...');
    const validation = await validateApiKeyAsync(apiKey!);

    if (!validation.valid) {
      OutputHelper.error(`API key validation failed: ${validation.reason}`);
      process.exit(1);
    }

    await saveApiKeyAsync(apiKey!);
    OutputHelper.info('API key is valid.');
    OutputHelper.info('Saved to ~/.nevermore/credentials.json');
  };

  private _showStatusAsync = async (args: LoginArgs): Promise<void> => {
    if (args.apiKey) {
      OutputHelper.info('API key: provided via --api-key flag');
      return;
    }
    if (process.env.ROBLOX_OPEN_CLOUD_API_KEY) {
      OutputHelper.info(
        'API key: provided via ROBLOX_OPEN_CLOUD_API_KEY environment variable'
      );
      return;
    }
    if (process.env.ROBLOX_UNIT_TEST_API_KEY) {
      OutputHelper.info(
        'API key: provided via ROBLOX_UNIT_TEST_API_KEY environment variable'
      );
      return;
    }

    const stored = await loadStoredApiKeyAsync();
    if (stored) {
      const masked =
        stored.length > 8
          ? stored.slice(0, 4) + '...' + stored.slice(-4)
          : '****';
      OutputHelper.info(`API key: stored in ~/.nevermore/credentials.json (${masked})`);

      OutputHelper.info('Validating stored key...');
      const validation = await validateApiKeyAsync(stored);
      if (validation.valid) {
        OutputHelper.info('Key is valid.');
      } else {
        OutputHelper.warn(
          `Key may be invalid: ${validation.reason}. Run "nevermore login --force" to update.`
        );
      }
      return;
    }

    OutputHelper.warn('Not logged in. Run "nevermore login" to set up credentials.');
  };

  private _findExistingKeySourceAsync = async (): Promise<
    string | undefined
  > => {
    if (process.env.ROBLOX_OPEN_CLOUD_API_KEY) {
      return 'ROBLOX_OPEN_CLOUD_API_KEY environment variable';
    }
    if (process.env.ROBLOX_UNIT_TEST_API_KEY) {
      return 'ROBLOX_UNIT_TEST_API_KEY environment variable';
    }
    const stored = await loadStoredApiKeyAsync();
    if (stored) {
      return '~/.nevermore/credentials.json';
    }
    return undefined;
  };
}
