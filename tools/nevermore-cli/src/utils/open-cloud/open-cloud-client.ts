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
  body: string
): string {
  return [
    `${action} failed: ${status} ${statusText}: ${body}`,
    '',
    `Required scope: ${scope}`,
    `Universe: ${universeId}  Place: ${placeId}`,
    '',
    'Make sure the experience is added to your API key\'s allow list.',
    '',
    `Place: https://www.roblox.com/games/${placeId}/place`,
    `Credentials: https://create.roblox.com/dashboard/credentials`,
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

    const response = await this._rateLimiter.fetchAsync(
      `https://apis.roblox.com/universes/v1/${universeId}/places/${placeId}/versions?versionType=${versionType}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/octet-stream',
          Accept: 'application/json',
          'X-API-Key': this._apiKey,
        },
        body,
      }
    );

    if (!response.ok) {
      const text = await response.text();
      if (response.status === 401 || response.status === 403) {
        throw new Error(
          formatAuthError('Upload', 'universe-places:write', universeId, placeId, response.status, response.statusText, text)
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
    const response = await this._rateLimiter.fetchAsync(
      `https://apis.roblox.com/cloud/v2/universes/${universeId}/places/${placeId}/versions/${placeVersion}/luau-execution-session-tasks`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': this._apiKey,
        },
        body: JSON.stringify({ script }),
      }
    );

    if (!response.ok) {
      const text = await response.text();
      if (response.status === 401 || response.status === 403) {
        throw new Error(
          formatAuthError('Luau execution', 'universe.place.luau-execution-session:write', universeId, placeId, response.status, response.statusText, text)
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
