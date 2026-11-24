import * as fs from 'fs/promises';
import * as path from 'path';
import { Readable, Transform } from 'node:stream';
import nodeFetch from 'node-fetch';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { type LogFetchStats } from '../jobs/log-fetch-stats.js';
import { recompressPlace } from '../place/place-recompression.js';
import { extractApiMessage, formatAuthError } from './open-cloud-errors.js';
import { OpenCloudPlaceClient } from './open-cloud-place-client.js';
import { type FetchLike, type RateLimitWait } from './rate-limiter.js';

/**
 * The largest place file the place version endpoint accepts, measured: 150 MiB
 * exactly uploads, one byte more is refused from `Content-Length` before the
 * body is sent, as `400 InvalidRequest: "Request upload was interrupted before
 * completion."` — and somewhere past ~200 MB as `413 Payload Too Large`.
 * Neither says anything about size, so it is checked here first.
 *
 * Not the 100 MB Roblox documents as supported
 * (https://create.roblox.com/docs/projects/place-files); that is where Studio
 * saving "might fail", not where the API cuts off.
 */
export const PLACE_UPLOAD_MAX_BYTES = 150 * 1024 * 1024;

export const LUAU_EXECUTION_SCRIPT_MAX_BYTES = 4_000_000;

/**
 * One engine message, with the severity Open Cloud reported for it.
 *
 * A message is not a line: an error arrives with its whole traceback attached,
 * so `message` can span several. `messageType` is OUTPUT, WARNING or ERROR.
 */
export interface TaskLogMessage {
  message: string;
  messageType?: string;
}

/** A task's log text together with what the fetch had to do to collect it. */
export interface TaskLogFetch {
  text: string;
  stats: LogFetchStats;
  /**
   * The same output as `text`, still split into typed messages. Kept because
   * severity is the API's to state and cannot be recovered from the joined
   * text: a traceback's continuation lines look like ordinary output.
   */
  messages: TaskLogMessage[];
}

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
  /**
   * What the script returned, populated on COMPLETE. `results` is a flat array
   * of the returned values — `return t, "s", 42` arrives as three entries —
   * natively typed: Roblox serializes them itself, so a returned Lua table is
   * real nested JSON here, not a JSON string. (Which is also why a script must
   * not JSONEncode its result: that lands as a double-encoded string.)
   *
   * Absent whenever the task produced no result. A FAILED task carries no
   * `output` at all, with no error message explaining why — and an oversize
   * return value (~4MB observed; ~2MB still arrives complete) fails the task
   * exactly that way rather than truncating the value.
   */
  output?: { results?: unknown[] };
  /** Error details (populated on FAILED). */
  error?: { code?: string; message?: string };
}

/**
 * The values a finished task's script returned, or `undefined` when the task
 * reported no result at all.
 *
 * The distinction matters: `undefined` means nothing came back to read, so a
 * caller can fall back to the task's logs, while `[]` means the task did report
 * a result and the script returned nothing — no fallback will find more.
 */
export function getTaskReturnValues(task: LuauTask): unknown[] | undefined {
  if (!task.output) {
    return undefined;
  }
  return task.output.results ?? [];
}

/** Who owns a newly created asset. */
export type AssetCreator = { userId: number } | { groupId: number };

export interface AssetFile {
  filePath: string;
  /** MIME type of the file. The Assets API picks its importer from it. */
  contentType: string;
}

export interface CreateAssetOptions extends AssetFile {
  /** `Model`, `Image`, `Audio`, ... as the Assets API spells them. */
  assetType: string;
  displayName: string;
  description: string;
  creator: AssetCreator;
}

/**
 * The long-running operation every asset upload returns. Creating an asset is
 * not synchronous — the file is imported and moderated first — so the id only
 * exists once the operation reports `done`.
 */
export interface AssetOperation {
  /** `operations/{operationId}` */
  path: string;
  done?: boolean;
  response?: {
    /** A string in practice, though the API's own schema calls it an integer. */
    assetId?: string | number;
    revisionId?: string;
    moderationResult?: { moderationState?: string };
  };
  error?: { code?: number | string; message?: string };
}

export interface UploadedAsset {
  assetId: number;
  revisionId?: string;
  /**
   * `Approved`, `Reviewing`, ... exactly as the API reports it — which is not
   * the `MODERATION_STATE_APPROVED` spelling its documentation shows. Audio
   * routinely finishes uploading while still `Reviewing`.
   */
  moderationState?: string;
}

const ASSETS_API_URL = 'https://apis.roblox.com/assets/v1';
const ASSET_OPERATION_POLL_MS = 2000;
const ASSET_OPERATION_TIMEOUT_MS = 5 * 60 * 1000;

function formatAssetApiError(
  action: string,
  status: number,
  statusText: string,
  body: string,
  method: string,
  url: string
): string {
  if (status !== 401 && status !== 403) {
    return `${action} failed: ${status} ${statusText}: ${body}`;
  }

  const apiMessage = extractApiMessage(body);
  const headline = apiMessage
    ? `${action} failed: ${apiMessage} (${status})`
    : `${action} failed: ${status} ${statusText}`;

  const dim = OutputHelper.formatDim;
  const info = OutputHelper.formatInfo;

  return [
    OutputHelper.formatError(headline),
    '',
    `  ${dim('Scope:')}       asset:read, asset:write`,
    '',
    OutputHelper.formatWarning(
      'Ensure the API key has the Assets API with both Read and Write, and ' +
        'that its owner may create assets for the user or group named as creator.'
    ),
    '',
    `  ${dim('Credentials:')} ${info(
      'https://create.roblox.com/dashboard/credentials'
    )}`,
    `  ${dim('Route:')}       ${dim(`${method} ${url}`)}`,
  ].join('\n');
}

/** Extends rather than wraps `OpenCloudPlaceClient`, so both share one rate limiter. */
export class OpenCloudClient extends OpenCloudPlaceClient {
  async uploadPlaceAsync(
    universeId: number,
    placeId: number,
    rbxlPath: string,
    publish?: boolean,
    onProgress?: (transferredBytes: number, totalBytes: number) => void,
    onRateLimitWait?: (wait: RateLimitWait) => void
  ): Promise<number> {
    OutputHelper.verbose(
      `Uploading to https://www.roblox.com/games/${placeId}/place ...`
    );

    const apiKey = await this._resolveApiKeyAsync();
    const fileBuffer = _recompressForUpload(
      rbxlPath,
      await fs.readFile(rbxlPath)
    );
    const totalBytes = fileBuffer.length;
    if (totalBytes > PLACE_UPLOAD_MAX_BYTES) {
      throw new Error(
        `Upload failed: ${path.basename(rbxlPath)} is ${_formatMegabytes(
          totalBytes
        )}, over the Open Cloud ${_formatMegabytes(
          PLACE_UPLOAD_MAX_BYTES
        )} place upload limit`
      );
    }
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
      onWait: onRateLimitWait,
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
    timeoutMs?: number,
    onRateLimitWait?: (wait: RateLimitWait) => void
  ): Promise<LuauTask> {
    const scriptBytes = Buffer.byteLength(script, 'utf-8');
    if (scriptBytes > LUAU_EXECUTION_SCRIPT_MAX_BYTES) {
      throw new Error(
        `The script is ${_formatMegabytes(
          scriptBytes
        )}, over the Open Cloud limit of 4 MB for a Luau execution script`
      );
    }

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

    const response = await this._rateLimiter.fetchAsync(
      url,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: JSON.stringify(body),
      },
      { onWait: onRateLimitWait }
    );

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
    onProgress?: (state: LuauTask['state']) => void,
    onRateLimitWait?: (wait: RateLimitWait) => void
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
        },
        { onWait: onRateLimitWait }
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

  /**
   * Fetch raw log text from a completed Luau execution task, along with the
   * shape of the fetch that produced it.
   *
   * Retries a few times if the API returns empty logs, since the test runner
   * always produces at least some output. The reported `requests` count spans
   * every attempt, so a fetch that only filled in on its third try says so.
   */
  async getRawTaskLogsAsync(taskPath: string): Promise<TaskLogFetch> {
    const maxAttempts = 3;
    const retryDelayMs = 1000;
    let requests = 0;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      const fetched = await this._fetchRawLogsAsync(taskPath);
      requests += fetched.stats.requests;

      if (fetched.text || attempt === maxAttempts) {
        return {
          text: fetched.text,
          stats: { ...fetched.stats, requests },
          messages: fetched.messages,
        };
      }
      await new Promise((resolve) => setTimeout(resolve, retryDelayMs));
    }

    // Unreachable, but satisfies the type checker
    return this._fetchRawLogsAsync(taskPath);
  }

  private async _fetchRawLogsAsync(taskPath: string): Promise<TaskLogFetch> {
    const apiKey = await this._resolveApiKeyAsync();
    // Arrival order, deliberately. Do not sort by createTime: every print in a
    // single frame shares one value, so it cannot order them anyway, and the
    // fractional digit count varies, so comparing the strings reorders them.
    const messages: TaskLogMessage[] = [];
    let pageToken: string | undefined;
    let pagesFetched = 0;
    let entriesFetched = 0;

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
          messages.push(
            ...entry.structuredMessages.map((msg) => ({
              message: msg.message,
              messageType: msg.messageType,
            }))
          );
        } else if (entry.messages?.length) {
          // The flat view carries no severity, which stays absent rather than
          // being guessed at.
          messages.push(...entry.messages.map((message) => ({ message })));
        }
      }

      entriesFetched += (data.luauExecutionSessionTaskLogs ?? []).length;
      pagesFetched++;
      pageToken = data.nextPageToken || undefined;
    } while (pageToken);

    const text = messages.map((entry) => entry.message).join('\n');

    const stats: LogFetchStats = {
      requests: pagesFetched,
      pages: pagesFetched,
      entries: entriesFetched,
      messages: messages.length,
      chars: text.length,
    };

    // Log volume is the prime suspect when engine output goes missing between
    // the task and the parser, and the parser cannot tell a short run from a
    // truncated fetch. Handed out with the text rather than only printed, so
    // the diagnostic that finds the output missing can say what the fetch saw.
    OutputHelper.verbose(
      `[open-cloud] Task logs: ${stats.pages} page(s), ${stats.entries} entries, ` +
        `${stats.messages} messages, ${stats.chars} chars`
    );

    return { text, stats, messages };
  }

  /**
   * Start uploading a file as a new asset via the Open Cloud Assets API
   * (`asset:read` and `asset:write`). Returns the operation to hand to
   * {@link pollAssetOperationAsync}; the asset has no id until that finishes.
   */
  async createAssetAsync(options: CreateAssetOptions): Promise<AssetOperation> {
    const { creator } = options;
    return this._sendAssetAsync(
      'POST',
      `${ASSETS_API_URL}/assets`,
      {
        assetType: options.assetType,
        displayName: options.displayName,
        description: options.description,
        creationContext: {
          creator:
            'userId' in creator
              ? { userId: String(creator.userId) }
              : { groupId: String(creator.groupId) },
        },
      },
      options
    );
  }

  /**
   * Start replacing an existing asset's file, keeping its id — the upload
   * becomes a new version of the same asset. The API only does this for models.
   */
  async updateAssetContentAsync(
    assetId: number,
    file: AssetFile
  ): Promise<AssetOperation> {
    return this._sendAssetAsync(
      'PATCH',
      `${ASSETS_API_URL}/assets/${assetId}`,
      { assetId },
      file
    );
  }

  /**
   * Wait for an asset upload to finish and return the asset it produced.
   *
   * Throws if the operation reports an error or outlives `timeoutMs`. A timeout
   * is not a failed upload: Roblox may still finish creating the asset, which
   * is why the message says to look before uploading again.
   */
  async pollAssetOperationAsync(
    operation: AssetOperation,
    timeoutMs: number = ASSET_OPERATION_TIMEOUT_MS
  ): Promise<UploadedAsset> {
    const apiKey = await this._resolveApiKeyAsync();
    const url = `${ASSETS_API_URL}/${operation.path}`;
    const maxPolls = Math.ceil(timeoutMs / ASSET_OPERATION_POLL_MS);

    let current = operation;
    for (let poll = 0; !current.done && poll < maxPolls; poll++) {
      await new Promise((resolve) =>
        setTimeout(resolve, ASSET_OPERATION_POLL_MS)
      );

      const response = await this._rateLimiter.fetchAsync(url, {
        method: 'GET',
        headers: { 'x-api-key': apiKey },
      });
      if (!response.ok) {
        throw new Error(
          formatAssetApiError(
            'Read asset upload status',
            response.status,
            response.statusText,
            await response.text(),
            'GET',
            url
          )
        );
      }
      current = (await response.json()) as AssetOperation;
    }

    if (!current.done) {
      throw new Error(
        `Asset upload ${operation.path} did not finish within ` +
          `${Math.round(timeoutMs / 1000)}s. Roblox may still create the ` +
          `asset — check https://create.roblox.com/dashboard/creations ` +
          `before uploading it again.`
      );
    }
    if (current.error) {
      throw new Error(
        `Asset upload failed: ${
          current.error.message ?? JSON.stringify(current.error)
        }`
      );
    }

    const assetId = Number(current.response?.assetId);
    if (!Number.isSafeInteger(assetId) || assetId < 1) {
      throw new Error(
        `Asset upload ${operation.path} finished without an asset id: ` +
          JSON.stringify(current)
      );
    }

    return {
      assetId,
      revisionId: current.response?.revisionId,
      moderationState: current.response?.moderationResult?.moderationState,
    };
  }

  /**
   * Who owns a universe: the user or group its assets should belong to if the
   * experience is to use them. Needs no scope beyond a valid key.
   */
  async getUniverseOwnerAsync(universeId: number): Promise<AssetCreator> {
    const apiKey = await this._resolveApiKeyAsync();
    const url = `https://apis.roblox.com/cloud/v2/universes/${universeId}`;

    const response = await this._rateLimiter.fetchAsync(url, {
      method: 'GET',
      headers: { 'x-api-key': apiKey },
    });
    if (!response.ok) {
      throw new Error(
        `Read universe ${universeId} failed: ${response.status} ${response.statusText}`
      );
    }

    // Exactly one of the two is present: `users/123` or `groups/456`.
    const universe = (await response.json()) as {
      user?: string;
      group?: string;
    };
    const userId = Number(universe.user?.match(/^users\/(\d+)$/)?.[1]);
    if (Number.isSafeInteger(userId)) {
      return { userId };
    }
    const groupId = Number(universe.group?.match(/^groups\/(\d+)$/)?.[1]);
    if (Number.isSafeInteger(groupId)) {
      return { groupId };
    }
    throw new Error(`Universe ${universeId} did not report an owner`);
  }

  /** The user the API key acts as — whoever created it. */
  async getApiKeyUserIdAsync(): Promise<number> {
    const apiKey = await this._resolveApiKeyAsync();
    const url = 'https://apis.roblox.com/api-keys/v1/introspect';

    // The key travels in the body here, not the usual header.
    const response = await this._rateLimiter.fetchAsync(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ apiKey }),
    });
    if (!response.ok) {
      throw new Error(
        `Read API key owner failed: ${response.status} ${response.statusText}`
      );
    }

    const key = (await response.json()) as { authorizedUserId?: number };
    if (!Number.isSafeInteger(key.authorizedUserId)) {
      throw new Error('The API key did not report which user it belongs to');
    }
    return key.authorizedUserId!;
  }

  private async _sendAssetAsync(
    method: 'POST' | 'PATCH',
    url: string,
    request: Record<string, unknown>,
    file: AssetFile
  ): Promise<AssetOperation> {
    const apiKey = await this._resolveApiKeyAsync();
    const fileBuffer = await fs.readFile(file.filePath);

    const form = new FormData();
    form.append('request', JSON.stringify(request));
    form.append(
      'fileContent',
      new Blob([new Uint8Array(fileBuffer)], { type: file.contentType }),
      path.basename(file.filePath)
    );

    // No Content-Type header: fetch writes the multipart boundary itself, and
    // setting one by hand sends a body the API cannot split into parts.
    const response = await this._rateLimiter.fetchAsync(url, {
      method,
      headers: { 'x-api-key': apiKey },
      body: form,
    });

    if (!response.ok) {
      throw new Error(
        formatAssetApiError(
          method === 'POST' ? 'Create asset' : 'Update asset',
          response.status,
          response.statusText,
          await response.text(),
          method,
          url
        )
      );
    }

    return (await response.json()) as AssetOperation;
  }
}

/**
 * The bytes to upload for a place file: recompressed when that is possible,
 * the file as read when it is not. An upload never fails for want of zstd —
 * it only goes up larger.
 */
function _recompressForUpload(rbxlPath: string, fileBuffer: Buffer): Buffer {
  const name = path.basename(rbxlPath);
  const result = recompressPlace(fileBuffer);

  if (result.kind === 'recompressed') {
    OutputHelper.verbose(
      `Recompressed ${name}: ${_formatMegabytes(
        result.originalBytes
      )} -> ${_formatMegabytes(result.data.length)}`
    );
  } else if (result.kind === 'unsupported') {
    OutputHelper.warn(
      `Uploading ${name} as built (${_formatMegabytes(
        fileBuffer.length
      )}) without recompressing it: ${result.reason}`
    );
  }

  return result.data;
}

/** In Roblox's MB, which are 1024 * 1024 bytes. */
function _formatMegabytes(bytes: number): string {
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}
