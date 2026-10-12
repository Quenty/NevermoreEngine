import * as fs from 'fs/promises';
import * as path from 'path';
import { Readable, Transform } from 'node:stream';
import nodeFetch from 'node-fetch';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { RateLimiter, type FetchLike } from './rate-limiter.js';
import {
  parseTestLogs,
  type ParsedTestLogs,
} from '../testing/test-log-parser.js';
import { type LogFetchStats } from '../testing/log-fetch-stats.js';

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

export interface OpenCloudClientOptions {
  apiKey: string | (() => Promise<string>);
  rateLimiter: RateLimiter;
}

/**
 * Which end of a place's version history to resolve. Mirrors the `versionType`
 * the place-publishing API takes on upload, lowercased to match how it is
 * written in deploy.nevermore.json.
 */
export type PlaceVersionType = 'saved' | 'published';

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

/** Pull the human-readable message out of an Open Cloud error body. */
function _extractApiMessage(body: string): string {
  try {
    const parsed = JSON.parse(body);
    if (Array.isArray(parsed.errors) && parsed.errors[0]?.message) {
      return parsed.errors[0].message;
    }
    if (typeof parsed.message === 'string') {
      return parsed.message;
    }
  } catch {
    // Not JSON
  }
  return '';
}

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

  const apiMessage = _extractApiMessage(body);
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
  const apiMessage = _extractApiMessage(body);

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
    return parseTestLogs(raw.text);
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
   * Resolve the newest saved or published version number of a place, via the
   * Open Cloud Assets API (`asset:read` scope). The returned number is the same
   * value the Asset Delivery API's `/version/{n}` route expects, so it can be
   * written straight into a `basePlace.version` pin.
   *
   * This used to add that `legacy-asset:manage` grants `asset:read` too. They
   * are separate boxes on the credentials page and nothing here ever verified
   * the implication, so the claim is gone rather than restated — it had already
   * been copied into the `nevermore login` instructions as fact once.
   *
   * `saved` is the newest version of any kind — Studio saves and publishes
   * share one increasing version sequence. `published` is the newest version
   * that actually went live, which is what players see and what a deploy
   * merging against a base place normally wants.
   *
   * The endpoint pages newest-first, which is what makes this affordable: an
   * actively-developed place accumulates tens of thousands of versions, and we
   * never walk the history. `saved` is the first entry of the first page, and
   * `published` only walks back as far as the most recent live version — one
   * page unless the place has been saved 50+ times without publishing. The scan
   * is capped so a never-published place fails fast instead of paging forever.
   */
  async resolveLatestPlaceVersionAsync(
    universeId: number,
    placeId: number,
    versionType: PlaceVersionType
  ): Promise<number> {
    const apiKey = await this._resolveApiKeyAsync();
    let pageToken: string | undefined;
    let previousVersion: number | undefined;

    for (let page = 0; page < VERSION_SCAN_MAX_PAGES; page++) {
      const url =
        `https://apis.roblox.com/assets/v1/assets/${placeId}/versions` +
        `?maxPageSize=${VERSION_SCAN_PAGE_SIZE}` +
        (pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : '');

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

      const data = (await response.json()) as {
        assetVersions?: AssetVersion[];
        nextPageToken?: string;
      };

      const page = (data.assetVersions ?? []).map((assetVersion) => ({
        versionNumber: _parseAssetVersionNumber(placeId, assetVersion),
        published: assetVersion.published === true,
      }));

      // Everything here rests on the API paging newest-first, and a `saved`
      // lookup answers from the very first entry — so the whole page is checked
      // before anything is returned. Validating only as far as the match would
      // leave the common case unchecked and quietly pin a years-old build.
      for (const { versionNumber } of page) {
        if (previousVersion != null && versionNumber >= previousVersion) {
          throw new Error(
            `Read place version failed: place ${placeId} returned version ` +
              `${versionNumber} after ${previousVersion}. The Assets API is no ` +
              `longer paging newest-first, so "${versionType}" cannot be resolved ` +
              `safely — pin an explicit version number in deploy.nevermore.json.`
          );
        }
        previousVersion = versionNumber;
      }

      // `published` is omitted rather than false on save-only versions.
      const match = page.find(
        (entry) => versionType === 'saved' || entry.published
      );
      if (match) {
        return match.versionNumber;
      }

      pageToken = data.nextPageToken;
      if (!pageToken) {
        break;
      }
    }

    throw new Error(
      `Place ${placeId} has no ${versionType} version` +
        (pageToken
          ? ` in its most recent ${
              VERSION_SCAN_MAX_PAGES * VERSION_SCAN_PAGE_SIZE
            } versions`
          : '') +
        `. Pin an explicit version number in deploy.nevermore.json, or publish the place once.`
    );
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

/** How the Assets API reports one entry of a place's version history. */
interface AssetVersion {
  /** `assets/{assetId}/versions/{versionNumber}` */
  path?: string;
  /** Present and true only once the version has been published live. */
  published?: boolean;
}

const VERSION_SCAN_PAGE_SIZE = 50;
const VERSION_SCAN_MAX_PAGES = 20;

function _parseAssetVersionNumber(
  placeId: number,
  version: AssetVersion
): number {
  const versionNumber = Number(version.path?.split('/').pop());
  if (!Number.isInteger(versionNumber) || versionNumber < 1) {
    throw new Error(
      `Read place version failed: place ${placeId} returned an unparseable ` +
        `version path "${version.path}"`
    );
  }
  return versionNumber;
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
