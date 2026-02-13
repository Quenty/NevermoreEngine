import * as fs from 'fs/promises';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { RateLimiter } from './rate-limiter.js';

export interface LuauTask {
  path: string;
  createTime: string;
  updateTime: string;
  user: string;
  state:
    | 'STATE_UNSPECIFIED'
    | 'QUEUED'
    | 'PROCESSING'
    | 'CANCELLED'
    | 'COMPLETE'
    | 'FAILED';
  script: string;
}

export interface TaskLogsResult {
  success: boolean;
  logs: string;
}

interface OpenCloudClientOptions {
  apiKey: string;
  rateLimiter: RateLimiter;
}

function formatAuthError(
  action: string,
  scope: string,
  universeId: number,
  placeId: number,
  status: number,
  statusText: string,
  body: string,
  method: string,
  url: string
): string {
  // Extract human-readable message from JSON body if possible
  let apiMessage = '';
  try {
    const parsed = JSON.parse(body);
    if (Array.isArray(parsed.errors) && parsed.errors[0]?.message) {
      apiMessage = parsed.errors[0].message;
    } else if (typeof parsed.message === 'string') {
      apiMessage = parsed.message;
    }
  } catch {
    // Not JSON
  }

  const headline = apiMessage
    ? `${action} failed: ${apiMessage} (${status})`
    : `${action} failed: ${status} ${statusText}`;

  const dim = OutputHelper.formatDim;
  const info = OutputHelper.formatInfo;

  return [
    OutputHelper.formatError(headline),
    '',
    `  ${dim('Scope:')}       ${scope}`,
    `  ${dim('Universe:')}    ${universeId}`,
    `  ${dim('Place:')}       ${placeId}`,
    '',
    OutputHelper.formatWarning('Ensure the API key has the required scope and the experience is on its allow list.'),
    '',
    `  ${dim('Place:')}       ${info(`https://www.roblox.com/games/${placeId}/place`)}`,
    `  ${dim('Credentials:')} ${info('https://create.roblox.com/dashboard/credentials')}`,
    `  ${dim('Route:')}       ${dim(`${method} ${url}`)}`,
  ].join('\n');
}

export class OpenCloudClient {
  private _apiKey: string;
  private _rateLimiter: RateLimiter;

  constructor(options: OpenCloudClientOptions) {
    this._apiKey = options.apiKey;
    this._rateLimiter = options.rateLimiter;
  }

  async uploadPlaceAsync(
    universeId: number,
    placeId: number,
    rbxlPath: string,
    publish?: boolean
  ): Promise<number> {
    OutputHelper.info(`Uploading to https://www.roblox.com/games/${placeId}/place ...`);

    const fileBuffer = await fs.readFile(rbxlPath);
    const body = new Uint8Array(fileBuffer);
    const versionType = publish ? 'Published' : 'Saved';
    const url = `https://apis.roblox.com/universes/v1/${universeId}/places/${placeId}/versions?versionType=${versionType}`;

    const response = await this._rateLimiter.fetchAsync(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/octet-stream',
        Accept: 'application/json',
        'X-API-Key': this._apiKey,
      },
      body,
    });

    if (!response.ok) {
      const text = await response.text();
      if (response.status === 401 || response.status === 403) {
        throw new Error(
          formatAuthError('Upload', 'universe-places:write', universeId, placeId, response.status, response.statusText, text, 'POST', url)
        );
      }
      throw new Error(
        `Upload failed: ${response.status} ${response.statusText}: ${text}`
      );
    }

    const data = (await response.json()) as { versionNumber: number };
    return data.versionNumber;
  }

  async createExecutionTaskAsync(
    universeId: number,
    placeId: number,
    placeVersion: number,
    script: string
  ): Promise<LuauTask> {
    const url = `https://apis.roblox.com/cloud/v2/universes/${universeId}/places/${placeId}/versions/${placeVersion}/luau-execution-session-tasks`;

    const response = await this._rateLimiter.fetchAsync(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': this._apiKey,
      },
      body: JSON.stringify({ script }),
    });

    if (!response.ok) {
      const text = await response.text();
      if (response.status === 401 || response.status === 403) {
        throw new Error(
          formatAuthError('Luau execution', 'universe.place.luau-execution-session:write', universeId, placeId, response.status, response.statusText, text, 'POST', url)
        );
      }
      throw new Error(`Create task failed: ${response.status} ${response.statusText}: ${text}`);
    }

    return (await response.json()) as LuauTask;
  }

  async pollTaskCompletionAsync(
    taskPath: string,
    onProgress?: () => void
  ): Promise<LuauTask> {
    const pollIntervalMs = 3000;

    while (true) {
      const response = await this._rateLimiter.fetchAsync(
        `https://apis.roblox.com/cloud/v2/${taskPath}`,
        {
          method: 'GET',
          headers: {
            'X-API-Key': this._apiKey,
          },
        }
      );

      if (!response.ok) {
        const text = await response.text();
        throw new Error(`Poll failed: ${response.status}: ${text}`);
      }

      const task = (await response.json()) as LuauTask;

      if (task.state !== 'PROCESSING' && task.state !== 'QUEUED') {
        return task;
      }

      if (onProgress) {
        onProgress();
      }

      await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
    }
  }

  async getTaskLogsAsync(taskPath: string): Promise<TaskLogsResult> {
    const response = await this._rateLimiter.fetchAsync(
      `https://apis.roblox.com/cloud/v2/${taskPath}/logs`,
      {
        method: 'GET',
        headers: {
          'X-API-Key': this._apiKey,
        },
      }
    );

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Get logs failed: ${response.status}: ${text}`);
    }

    const data = (await response.json()) as {
      luauExecutionSessionTaskLogs: Array<{ messages: string[] }>;
    };

    const messages =
      data.luauExecutionSessionTaskLogs?.[0]?.messages ?? [];
    const logs = messages.join('\n');

    const cleanLogs = logs.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');

    // Check for Jest-style test failures
    const failedSuites = cleanLogs.match(/Test Suites:\s*(\d+)\s+failed/);
    const failedTests = cleanLogs.match(/Tests:\s*(\d+)\s+failed/);
    const hasJestFailures =
      (failedSuites && parseInt(failedSuites[1], 10) > 0) ||
      (failedTests && parseInt(failedTests[1], 10) > 0);

    // Check for Luau runtime errors (stack traces)
    const hasRuntimeError = /Stack Begin\s/.test(cleanLogs);

    return {
      success: !hasJestFailures && !hasRuntimeError,
      logs,
    };
  }
}
