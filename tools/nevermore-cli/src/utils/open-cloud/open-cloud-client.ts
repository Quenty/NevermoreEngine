import * as fs from 'fs/promises';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { RateLimiter } from './rate-limiter.js';
import {
  parseTestLogs,
  type ParsedTestLogs,
} from '../testing/test-log-parser.js';

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

export interface OpenCloudClientOptions {
  apiKey: string | (() => Promise<string>);
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
    OutputHelper.formatWarning(
      'Ensure the API key has the required scope and the experience is on its allow list.'
    ),
    '',
    `  ${dim('Place:')}       ${info(
      `https://www.roblox.com/games/${placeId}/place`
    )}`,
    `  ${dim('Credentials:')} ${info(
      'https://create.roblox.com/dashboard/credentials'
    )}`,
    `  ${dim('Route:')}       ${dim(`${method} ${url}`)}`,
  ].join('\n');
}

export class OpenCloudClient {
  private _apiKey: string | undefined;
  private _apiKeySource: string | (() => Promise<string>);
  private _rateLimiter: RateLimiter;

  constructor(options: OpenCloudClientOptions) {
    this._apiKeySource = options.apiKey;
    if (typeof options.apiKey === 'string') {
      this._apiKey = options.apiKey;
    }
    this._rateLimiter = options.rateLimiter;
  }

  private async _resolveApiKeyAsync(): Promise<string> {
    if (this._apiKey != null) {
      return this._apiKey;
    }
    if (typeof this._apiKeySource === 'function') {
      this._apiKey = await this._apiKeySource();
      return this._apiKey;
    }
    return this._apiKeySource;
  }

  async uploadPlaceAsync(
    universeId: number,
    placeId: number,
    rbxlPath: string,
    publish?: boolean,
    onProgress?: (transferredBytes: number, totalBytes: number) => void
  ): Promise<number> {
    OutputHelper.verbose(
      `Uploading to https://www.roblox.com/games/${placeId}/place ...`
    );

    const apiKey = await this._resolveApiKeyAsync();
    const fileBuffer = await fs.readFile(rbxlPath);
    const totalBytes = fileBuffer.length;
    const versionType = publish ? 'Published' : 'Saved';
    const url = `https://apis.roblox.com/universes/v1/${universeId}/places/${placeId}/versions?versionType=${versionType}`;

    const headers: Record<string, string> = {
      'Content-Type': 'application/octet-stream',
      Accept: 'application/json',
      'X-API-Key': apiKey,
    };

    let response: Response;

    if (onProgress) {
      // Wrap the buffer in a ReadableStream that reports bytes as each chunk
      // is consumed by the transport, giving real-time upload progress.
      const CHUNK_SIZE = 64 * 1024;
      let offset = 0;
      const stream = new ReadableStream<Uint8Array>({
        pull(controller) {
          if (offset >= totalBytes) {
            controller.close();
            return;
          }
          const end = Math.min(offset + CHUNK_SIZE, totalBytes);
          controller.enqueue(fileBuffer.subarray(offset, end));
          offset = end;
          onProgress(offset, totalBytes);
        },
      });

      // fetch with ReadableStream body requires duplex: 'half' in Node
      response = await this._rateLimiter.fetchAsync(url, {
        method: 'POST',
        headers,
        body: stream,
        duplex: 'half',
      } as RequestInit);
    } else {
      response = await this._rateLimiter.fetchAsync(url, {
        method: 'POST',
        headers,
        body: new Uint8Array(fileBuffer),
      });
    }

    if (!response.ok) {
      const text = await response.text();
      if (response.status === 401 || response.status === 403) {
        throw new Error(
          formatAuthError(
            'Upload',
            'universe-places:write',
            universeId,
            placeId,
            response.status,
            response.statusText,
            text,
            'POST',
            url
          )
        );
      }
      if (response.status === 409) {
        const dim = OutputHelper.formatDim;
        const info = OutputHelper.formatInfo;
        throw new Error(
          [
            OutputHelper.formatError(
              'Upload failed: place is locked (409 Conflict)'
            ),
            '',
            '  This usually means someone has the place open in Team Create.',
            '  Close all Studio sessions for this place and try again.',
            '',
            `  ${dim('Place:')}    ${info(
              `https://www.roblox.com/games/${placeId}/place`
            )}`,
            `  ${dim('Route:')}    ${dim(`POST ${url}`)}`,
          ].join('\n')
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
    const apiKey = await this._resolveApiKeyAsync();
    const url = `https://apis.roblox.com/cloud/v2/universes/${universeId}/places/${placeId}/versions/${placeVersion}/luau-execution-session-tasks`;

    const response = await this._rateLimiter.fetchAsync(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: JSON.stringify({ script }),
    });

    if (!response.ok) {
      const text = await response.text();
      if (response.status === 401 || response.status === 403) {
        throw new Error(
          formatAuthError(
            'Luau execution',
            'universe.place.luau-execution-session:write',
            universeId,
            placeId,
            response.status,
            response.statusText,
            text,
            'POST',
            url
          )
        );
      }
      throw new Error(
        `Create task failed: ${response.status} ${response.statusText}: ${text}`
      );
    }

    return (await response.json()) as LuauTask;
  }

  async pollTaskCompletionAsync(
    taskPath: string,
    onProgress?: (state: LuauTask['state']) => void
  ): Promise<LuauTask> {
    const apiKey = await this._resolveApiKeyAsync();
    const pollIntervalMs = 3000;

    while (true) {
      const response = await this._rateLimiter.fetchAsync(
        `https://apis.roblox.com/cloud/v2/${taskPath}`,
        {
          method: 'GET',
          headers: {
            'X-API-Key': apiKey,
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
        onProgress(task.state);
      }

      await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
    }
  }

  async getTaskLogsAsync(taskPath: string): Promise<ParsedTestLogs> {
    const raw = await this.getRawTaskLogsAsync(taskPath);
    return parseTestLogs(raw);
  }

  /**
   * Fetch raw log text from a completed Luau execution task.
   * Retries a few times if the API returns empty logs, since the test runner
   * always produces at least some output.
   */
  async getRawTaskLogsAsync(taskPath: string): Promise<string> {
    const maxAttempts = 3;
    const retryDelayMs = 1000;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      const logs = await this._fetchRawLogsAsync(taskPath);
      if (logs || attempt === maxAttempts) {
        return logs;
      }
      await new Promise((resolve) => setTimeout(resolve, retryDelayMs));
    }

    // Unreachable, but satisfies the type checker
    return this._fetchRawLogsAsync(taskPath);
  }

  private async _fetchRawLogsAsync(taskPath: string): Promise<string> {
    const apiKey = await this._resolveApiKeyAsync();
    const response = await this._rateLimiter.fetchAsync(
      `https://apis.roblox.com/cloud/v2/${taskPath}/logs`,
      {
        method: 'GET',
        headers: {
          'X-API-Key': apiKey,
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

    const messages = data.luauExecutionSessionTaskLogs?.[0]?.messages ?? [];
    return messages.join('\n');
  }

  /**
   * Download a place file via the Asset Delivery API.
   * Requires the `legacy-asset:manage` scope on the API key.
   *
   * Two-step process: fetch a temporary CDN URL, then download the binary.
   */
  async downloadPlaceAsync(
    universeId: number,
    placeId: number
  ): Promise<Buffer> {
    const apiKey = await this._resolveApiKeyAsync();
    const url = `https://apis.roblox.com/asset-delivery-api/v1/assetId/${placeId}`;

    OutputHelper.verbose(
      `Downloading base place from https://www.roblox.com/games/${placeId}/place ...`
    );

    const response = await this._rateLimiter.fetchAsync(url, {
      method: 'GET',
      headers: {
        'x-api-key': apiKey,
      },
    });

    if (!response.ok) {
      const text = await response.text();
      if (response.status === 401 || response.status === 403) {
        throw new Error(
          formatAuthError(
            'Download place',
            'legacy-asset:manage',
            universeId,
            placeId,
            response.status,
            response.statusText,
            text,
            'GET',
            url
          )
        );
      }
      throw new Error(
        `Download place failed: ${response.status} ${response.statusText}: ${text}`
      );
    }

    const data = (await response.json()) as { location: string };
    if (!data.location) {
      throw new Error('Download place failed: no CDN location in response');
    }

    OutputHelper.verbose('Fetching place binary from CDN...');
    const cdnResponse = await fetch(data.location);
    if (!cdnResponse.ok) {
      throw new Error(
        `Download place CDN fetch failed: ${cdnResponse.status} ${cdnResponse.statusText}`
      );
    }

    const arrayBuffer = await cdnResponse.arrayBuffer();
    return Buffer.from(arrayBuffer);
  }
}
