import * as fs from 'fs/promises';
import { Readable, Transform } from 'node:stream';
import nodeFetch from 'node-fetch';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { RateLimiter, type FetchLike } from './rate-limiter.js';
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
  timeout?: string;
  /** Script return value (populated on COMPLETE). */
  output?: { results?: Array<{ value?: string }> };
  /** Error details (populated on FAILED). */
  error?: { code?: string; message?: string };
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

    // Stream the place binary so we can report byte-level upload progress. We
    // pin node-fetch here: undici (global fetch) cannot send a streaming request
    // body to the Open Cloud versions endpoint on Node 24 — it throws "expected
    // non-null body source" — whereas node-fetch's Node http stack accepts it.
    // Content-Length is set so the upload isn't chunked. The rate limiter
    // rebuilds this init per attempt, so each retry gets a fresh, un-disturbed
    // stream (and progress restarts, correctly mirroring the re-sent bytes).
    onProgress?.(0, totalBytes);
    const makeUploadInit = (): RequestInit => {
      let counted = 0;
      const counter = new Transform({
        transform(chunk, _enc, cb) {
          counted += chunk.length;
          onProgress?.(counted, totalBytes);
          cb(null, chunk);
        },
      });
      // Node stream body: valid for node-fetch, but outside the DOM RequestInit
      // type, so cast through unknown.
      return {
        method: 'POST',
        headers: { ...headers, 'Content-Length': String(totalBytes) },
        body: Readable.from(fileBuffer).pipe(counter),
      } as unknown as RequestInit;
    };

    const response = await this._rateLimiter.fetchAsync(url, makeUploadInit, {
      fetchImpl: nodeFetch as unknown as FetchLike,
    });

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
    script: string,
    timeoutMs?: number
  ): Promise<LuauTask> {
    const apiKey = await this._resolveApiKeyAsync();
    const url = `https://apis.roblox.com/cloud/v2/universes/${universeId}/places/${placeId}/versions/${placeVersion}/luau-execution-session-tasks`;

    const body: {
      script: string;
      timeout?: string;
      enableBinaryOutput?: boolean;
    } = { script, enableBinaryOutput: false };
    if (timeoutMs !== undefined) {
      // Roblox encodes durations as Google AIP duration strings (e.g. "120s").
      // The server uses this to cancel runaway scripts on its end and rejects
      // values outside [1, 300] seconds inclusive.
      const requestedSeconds = Math.ceil(timeoutMs / 1000);
      const clampedSeconds = Math.min(300, Math.max(1, requestedSeconds));
      if (requestedSeconds > clampedSeconds) {
        OutputHelper.warn(
          `Requested execution timeout of ${requestedSeconds}s exceeds the Open Cloud API maximum of 300s; clamping. The server will cancel the task if it runs longer than 5 minutes.`
        );
      }
      body.timeout = `${clampedSeconds}s`;
    }

    const response = await this._rateLimiter.fetchAsync(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: JSON.stringify(body),
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
    const messages: string[] = [];
    let pageToken: string | undefined;

    do {
      const url = new URL(`https://apis.roblox.com/cloud/v2/${taskPath}/logs`);
      url.searchParams.set('view', 'STRUCTURED');
      if (pageToken) {
        url.searchParams.set('pageToken', pageToken);
      }

      const response = await this._rateLimiter.fetchAsync(url.toString(), {
        method: 'GET',
        headers: {
          'X-API-Key': apiKey,
        },
      });

      if (!response.ok) {
        const text = await response.text();
        throw new Error(`Get logs failed: ${response.status}: ${text}`);
      }

      const data = (await response.json()) as {
        luauExecutionSessionTaskLogs?: Array<{
          messages?: string[];
          structuredMessages?: Array<{
            message: string;
            createTime: string;
            messageType: string;
          }>;
        }>;
        nextPageToken?: string;
      };

      for (const entry of data.luauExecutionSessionTaskLogs ?? []) {
        if (entry.structuredMessages?.length) {
          for (const msg of entry.structuredMessages) {
            messages.push(msg.message);
          }
        } else if (entry.messages?.length) {
          messages.push(...entry.messages);
        }
      }

      pageToken = data.nextPageToken || undefined;
    } while (pageToken);

    return messages.join('\n');
  }

  /**
   * Download a place file via the Asset Delivery API.
   * Requires the `legacy-asset:manage` scope on the API key.
   *
   * Two-step process: fetch a temporary CDN URL, then download the binary.
   *
   * Pass `version` to fetch a specific published version instead of the latest.
   * This is how deploys pin a `basePlace` so a broken Studio edit can't leak in.
   */
  async downloadPlaceAsync(
    universeId: number,
    placeId: number,
    onProgress?: (transferredBytes: number, totalBytes: number) => void,
    version?: number
  ): Promise<Buffer> {
    const apiKey = await this._resolveApiKeyAsync();
    const url =
      version != null
        ? `https://apis.roblox.com/asset-delivery-api/v1/assetId/${placeId}/version/${version}`
        : `https://apis.roblox.com/asset-delivery-api/v1/assetId/${placeId}`;

    OutputHelper.verbose(
      `Downloading base place${
        version != null ? ` v${version}` : ''
      } from https://www.roblox.com/games/${placeId}/place ...`
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

    // The Asset Delivery API reports a missing asset/version as HTTP 200 with an
    // `errors` array rather than an error status, so a bad `version` pin lands
    // here instead of the block above.
    const data = (await response.json()) as {
      location?: string;
      errors?: Array<{ code?: number; message?: string }>;
    };
    if (!data.location) {
      const apiMessage = data.errors?.[0]?.message;
      if (version != null) {
        throw new Error(
          `Base place ${placeId} has no version ${version}` +
            (apiMessage ? ` (${apiMessage})` : '') +
            `. Run "nevermore deploy version upgrade" to re-pin, or check the pinned version in deploy.nevermore.json.`
        );
      }
      throw new Error(
        `Download place failed: no CDN location in response` +
          (apiMessage ? `: ${apiMessage}` : '')
      );
    }

    OutputHelper.verbose('Fetching place binary from CDN...');
    return _fetchCdnBinaryAsync(data.location, onProgress);
  }

  /**
   * Resolve the current latest published version number of a place, via the
   * Open Cloud Assets API (`asset:read` scope; `legacy-asset:manage` also
   * grants it). The returned number is the same value the Asset Delivery API's
   * `/version/{n}` route expects, so it can be written straight into a
   * `basePlace.version` pin.
   */
  async getLatestPlaceVersionAsync(
    universeId: number,
    placeId: number
  ): Promise<number> {
    const apiKey = await this._resolveApiKeyAsync();
    const url = `https://apis.roblox.com/assets/v1/assets/${placeId}`;

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
            'Read place version',
            'asset:read',
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
        `Read place version failed: ${response.status} ${response.statusText}: ${text}`
      );
    }

    const data = (await response.json()) as { revisionId?: string };
    const version = Number(data.revisionId);
    if (!data.revisionId || !Number.isFinite(version)) {
      throw new Error(
        `Read place version failed: no revisionId for place ${placeId}`
      );
    }
    return version;
  }
}

const CDN_MAX_ATTEMPTS = 4;

async function _fetchCdnBinaryAsync(
  url: string,
  onProgress?: (transferredBytes: number, totalBytes: number) => void
): Promise<Buffer> {
  let lastError: unknown = null;
  for (let attempt = 1; attempt <= CDN_MAX_ATTEMPTS; attempt++) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return await _readBodyWithProgressAsync(response, onProgress);
      }
      lastError = new Error(
        `Download place CDN fetch failed: ${response.status} ${response.statusText}`
      );
      // 4xx (other than 408/429) won't fix itself — stop retrying.
      if (
        response.status >= 400 &&
        response.status < 500 &&
        response.status !== 408 &&
        response.status !== 429
      ) {
        throw lastError;
      }
    } catch (err) {
      lastError = err;
    }

    if (attempt === CDN_MAX_ATTEMPTS) {
      break;
    }
    const waitMs = Math.min(8000, 500 * Math.pow(2, attempt - 1));
    OutputHelper.warn(
      `CDN download attempt ${attempt}/${CDN_MAX_ATTEMPTS} failed (${
        lastError instanceof Error ? lastError.message : String(lastError)
      }). Retrying in ${(waitMs / 1000).toFixed(1)}s...`
    );
    await new Promise((resolve) => setTimeout(resolve, waitMs));
  }
  throw lastError ?? new Error('Download place CDN fetch failed');
}

async function _readBodyWithProgressAsync(
  response: Response,
  onProgress?: (transferredBytes: number, totalBytes: number) => void
): Promise<Buffer> {
  if (!onProgress || !response.body) {
    return Buffer.from(await response.arrayBuffer());
  }

  // Content-Length may be absent (chunked transfer); report 0 in that case
  // and let the formatter render "transferred so far" without a denominator.
  const contentLength = response.headers.get('content-length');
  const totalBytes = contentLength ? parseInt(contentLength, 10) : 0;

  const chunks: Uint8Array[] = [];
  let transferred = 0;
  const reader = response.body.getReader();
  onProgress(0, totalBytes);

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    transferred += value.byteLength;
    onProgress(transferred, totalBytes);
  }

  return Buffer.concat(chunks);
}
