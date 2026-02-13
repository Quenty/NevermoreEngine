import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import inquirer from 'inquirer';
import { OutputHelper } from '@quenty/cli-output-helpers';

export interface CredentialArgs {
  apiKey?: string;
  yes?: boolean;
}

const CREDENTIALS_DIR = path.join(os.homedir(), '.nevermore');
const CREDENTIALS_PATH = path.join(CREDENTIALS_DIR, 'credentials.json');

export function printApiKeySetupHelp(): void {
  console.log('');
  OutputHelper.info(
    'Create an API key at https://create.roblox.com/dashboard/credentials'
  );
  console.log('');
  console.log('Required permissions:');
  console.log('  - universe-places:write           (upload place files)');
  console.log(
    '  - universe.place.luau-execution-session:write  (run scripts)'
  );
  console.log(
    '  - universe.place.luau-execution-session:read   (read results)'
  );
  console.log('');
}

interface StoredCredentials {
  apiKey: string;
}

export async function loadStoredApiKeyAsync(): Promise<string | undefined> {
  try {
    const content = await fs.readFile(CREDENTIALS_PATH, 'utf-8');
    const credentials = JSON.parse(content) as StoredCredentials;
    return credentials.apiKey;
  } catch {
    return undefined;
  }
}

export async function saveApiKeyAsync(apiKey: string): Promise<void> {
  await fs.mkdir(CREDENTIALS_DIR, { recursive: true });
  const credentials: StoredCredentials = { apiKey };
  await fs.writeFile(CREDENTIALS_PATH, JSON.stringify(credentials, null, 2));
}

export async function clearApiKeyAsync(): Promise<void> {
  try {
    await fs.unlink(CREDENTIALS_PATH);
  } catch {
    // Already gone
  }
}

export async function getApiKeyAsync(args: CredentialArgs): Promise<string> {
  if (args.apiKey) {
    return args.apiKey;
  }

  if (process.env.ROBLOX_OPEN_CLOUD_API_KEY) {
    return process.env.ROBLOX_OPEN_CLOUD_API_KEY;
  }

  if (process.env.ROBLOX_UNIT_TEST_API_KEY) {
    return process.env.ROBLOX_UNIT_TEST_API_KEY;
  }

  const stored = await loadStoredApiKeyAsync();
  if (stored) {
    return stored;
  }

  if (!args.yes) {
    return await promptAndSaveApiKeyAsync();
  }

  throw new Error(
    [
      'No API key found. Provide one of:',
      '  - Run: nevermore login',
      '  - Set: ROBLOX_OPEN_CLOUD_API_KEY environment variable',
      '  - Pass: --api-key <key>',
    ].join('\n')
  );
}

export async function validateApiKeyAsync(
  apiKey: string
): Promise<{ valid: boolean; reason?: string }> {
  try {
    const response = await fetch(
      'https://apis.roblox.com/cloud/v2/universes/0',
      {
        method: 'GET',
        headers: { 'X-API-Key': apiKey },
      }
    );

    if (response.status === 401) {
      return { valid: false, reason: 'Invalid API key (401 Unauthorized)' };
    }

    return { valid: true };
  } catch (err) {
    return {
      valid: false,
      reason: `Could not reach Roblox API: ${err}`,
    };
  }
}

async function promptAndSaveApiKeyAsync(): Promise<string> {
  OutputHelper.warn('No API key found. Starting login...');
  printApiKeySetupHelp();

  const { apiKey } = await inquirer.prompt([
    {
      type: 'password',
      name: 'apiKey',
      message: 'Enter your Roblox Open Cloud API key:',
      mask: '*',
      validate: (input: string) =>
        input.length > 0 || 'API key cannot be empty',
    },
  ]);

  OutputHelper.info('Validating API key...');
  const validation = await validateApiKeyAsync(apiKey);

  if (!validation.valid) {
    throw new Error(`API key validation failed: ${validation.reason}`);
  }

  await saveApiKeyAsync(apiKey);
  OutputHelper.info('API key is valid. Saved to ~/.nevermore/credentials.json');
  console.log('');

  return apiKey;
}
