import {
  type WatchRegistrationRequest,
  type WatchRegistrationResult,
  type WatchRegistry,
  type WatchTriggerResult,
} from '@quenty/nevermore-deploy';

const DEFAULT_TIMEOUT_MS = 30_000;

export interface HttpWatchRegistryOptions {
  /** Full register endpoint, ending in the lease — `.../v1/register/7d/`. */
  registerUrl: string;
  timeoutMs?: number;
  /** Injected in tests. Defaults to the global fetch. */
  fetchImpl?: typeof fetch;
}

/**
 * `WatchRegistry` over the Roblox Analytics Watch API.
 *
 * One `POST /v1/register/{lease}` per invocation. The endpoint is whatever URL
 * `--watch` resolved to, so nothing here assumes a host, and the lease is
 * already the last path segment of that URL.
 *
 * The endpoint takes no `Authorization` header — the GitHub token travels in
 * `auth.github.token`, because the service holds it to dispatch with later
 * rather than using it to authenticate this call.
 */
export class HttpWatchRegistry implements WatchRegistry {
  private _registerUrl: string;
  private _timeoutMs: number;
  private _fetch: typeof fetch;

  constructor(options: HttpWatchRegistryOptions) {
    this._registerUrl = options.registerUrl;
    this._timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    this._fetch = options.fetchImpl ?? fetch;
  }

  async registerAsync(
    request: WatchRegistrationRequest
  ): Promise<WatchRegistrationResult> {
    const body = {
      name: request.monitorName,
      auth: {
        github: {
          token: request.githubToken,
          repository: request.repository,
        },
        ...(request.robloxApiKey
          ? { robloxOpenCloud: { apiKey: request.robloxApiKey } }
          : {}),
      },
      watches: request.watches.map((watch) => ({
        name: watch.name,
        source: {
          type: watch.source.type,
          universeId: watch.source.universeId,
          placeId: watch.source.placeId,
          versionType: watch.source.versionType,
        },
        // The kind travels with the value or not at all. Without it the service
        // ignores a baseline outright on the one transition it matters for —
        // the first registration that supplies an Open Cloud key — and the 422
        // that should catch a vocabulary mismatch can never fire.
        ...(watch.baselineVersion == null
          ? {}
          : {
              baselineVersion: watch.baselineVersion,
              ...(watch.baselineVersionKind == null
                ? {}
                : { baselineVersionKind: watch.baselineVersionKind }),
            }),
        action: watch.action,
      })),
      ...(request.cooldownSeconds == null
        ? {}
        : { cooldownSeconds: request.cooldownSeconds }),
    };

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this._timeoutMs);

    let response: Response;
    try {
      response = await this._fetch(this._registerUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
    } catch (err) {
      if (controller.signal.aborted) {
        throw new Error(
          `Watch registration timed out after ${this._timeoutMs}ms: ${this._registerUrl}`
        );
      }
      throw new Error(
        `Watch registration could not reach ${this._registerUrl}: ` +
          (err instanceof Error ? err.message : String(err))
      );
    } finally {
      clearTimeout(timeout);
    }

    const text = await _readTextAsync(response);
    if (!response.ok) {
      throw new Error(_describeFailure(response, text, request));
    }

    return _parseResult(text);
  }

  async triggerAsync(
    monitorId: string,
    credential: string,
    options: { watchName?: string } = {}
  ): Promise<WatchTriggerResult> {
    const url = `${this._apiBase()}/v1/monitors/${encodeURIComponent(
      monitorId
    )}/trigger`;

    const response = await this._fetchWithTimeoutAsync(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        // Unlike register, this endpoint authenticates the caller — the token
        // is the identity, so it travels as a bearer rather than in the body.
        Authorization: `Bearer ${credential}`,
      },
      body: JSON.stringify(
        options.watchName == null ? {} : { watchName: options.watchName }
      ),
    });

    const text = await _readTextAsync(response);
    if (!response.ok) {
      const detail = _extractError(text);
      throw new Error(
        `Forcing a dispatch failed (${response.status} ${response.statusText})` +
          (detail ? `: ${detail}` : '')
      );
    }

    try {
      const parsed = JSON.parse(text) as WatchTriggerResult;
      return { results: Array.isArray(parsed.results) ? parsed.results : [] };
    } catch {
      return { results: [] };
    }
  }

  /**
   * The API root, recovered from the register URL.
   *
   * `--watch` names the register endpoint because that is the one a user has to
   * type; every other call is derived from it. The lease-bearing
   * `/v1/register/<lease>/` suffix is the documented shape, so trimming it is
   * how a single flag reaches the rest of the API.
   */
  private _apiBase(): string {
    const marker = '/v1/register/';
    const index = this._registerUrl.indexOf(marker);
    if (index === -1) {
      throw new Error(
        `Cannot derive the watch API root from "${this._registerUrl}" — ` +
          `expected it to contain "${marker}".`
      );
    }
    return this._registerUrl.slice(0, index);
  }

  private async _fetchWithTimeoutAsync(
    url: string,
    init: RequestInit
  ): Promise<Response> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this._timeoutMs);
    try {
      return await this._fetch(url, { ...init, signal: controller.signal });
    } catch (err) {
      if (controller.signal.aborted) {
        throw new Error(
          `Watch request timed out after ${this._timeoutMs}ms: ${url}`
        );
      }
      throw new Error(
        `Watch request could not reach ${url}: ` +
          (err instanceof Error ? err.message : String(err))
      );
    } finally {
      clearTimeout(timeout);
    }
  }
}

/**
 * Turn a status code into something actionable. The API documents exactly what
 * each failure means, and every one of them has a different fix — a generic
 * "registration failed (403)" would send someone to the wrong place.
 *
 * The service's own message wins when it has one, since it knows specifics we
 * can only guess at; ours is the fallback for a bare status. Only the remedy is
 * always ours, and it is what the service never supplies.
 */
function _describeFailure(
  response: Response,
  text: string,
  request: WatchRegistrationRequest
): string {
  const detail = _extractError(text);

  const compose = (fallback: string, remedy?: string): string => {
    const head = detail || fallback;
    return remedy ? `${head}\n${remedy}` : head;
  };

  switch (response.status) {
    case 400:
      return compose(
        'The watch service rejected the registration as invalid.',
        'This is a bug in how the CLI built the request — please report it.'
      );
    case 401:
      return compose(
        'GitHub rejected the dispatch token.',
        'Set NEVERMORE_WATCH_TOKEN to a valid, unexpired token.'
      );
    case 403:
      return compose(
        `The dispatch token cannot write to ${request.repository}.`,
        `The token needs "actions: write" on ${request.repository}.`
      );
    case 409:
      return compose(
        `Watch quota exceeded for ${request.repository}.`,
        'Release monitors you no longer need, or let their leases expire.'
      );
    case 422: {
      // 422 is the service's "your config cannot work" answer, and it covers
      // several unrelated causes now — a missing workflow, an Open Cloud key
      // that cannot read a base place, a "saved" watch with no key, a baseline
      // in the wrong vocabulary. Its own message names which, so the only thing
      // worth adding is a remedy that could not already be in it. The scope
      // itself is deliberately not named here: this file would then be a second
      // place to correct when it is wrong, and it already has been once.
      const workflows = [
        ...new Set(
          request.watches.flatMap((w) =>
            w.action.type === 'github-workflow-dispatch'
              ? [w.action.workflow]
              : []
          )
        ),
      ];
      // Volunteering a workflow remedy for a monitor that dispatches none once
      // produced "Referenced: ." under a message about an API key scope.
      if (workflows.length === 0) {
        return compose('The watch service rejected the configuration.');
      }
      return compose(
        `A referenced workflow does not exist in ${request.repository}.`,
        `Workflows referenced: ${workflows.join(', ')}. A "watch" path in ` +
          'deploy.nevermore.json must name a workflow that exists on the ' +
          'dispatched ref.'
      );
    }
    default:
      return compose(
        `Watch registration failed (${response.status} ${response.statusText}).`
      );
  }
}

/** Pull the API's `{error, errors}` shape out, falling back to raw text. */
function _extractError(text: string): string {
  if (text === '') {
    return '';
  }
  try {
    const parsed = JSON.parse(text) as {
      error?: unknown;
      errors?: unknown[];
    };
    const parts: string[] = [];
    if (typeof parsed.error === 'string') {
      parts.push(parsed.error);
    }
    if (Array.isArray(parsed.errors) && parsed.errors.length > 0) {
      parts.push(JSON.stringify(parsed.errors));
    }
    return parts.length > 0 ? parts.join(' ') : text;
  } catch {
    return text;
  }
}

async function _readTextAsync(response: Response): Promise<string> {
  try {
    return (await response.text()).trim();
  } catch {
    return '';
  }
}

/**
 * Read back the fields worth reporting. A 2xx whose body we cannot parse still
 * counts as registered — the service accepted it, and failing here would claim
 * otherwise.
 */
function _parseResult(text: string): WatchRegistrationResult {
  if (text === '') {
    return {};
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return {};
  }
  if (typeof parsed !== 'object' || parsed === null) {
    return {};
  }

  const record = parsed as Record<string, unknown>;
  const result: WatchRegistrationResult = {};
  if (typeof record['monitorId'] === 'string') {
    result.monitorId = record['monitorId'];
  }
  if (typeof record['revision'] === 'string') {
    result.revision = record['revision'];
  }
  if (typeof record['leaseExpiresAt'] === 'string') {
    result.leaseExpiresAt = record['leaseExpiresAt'];
  }
  if (typeof record['changed'] === 'boolean') {
    result.changed = record['changed'];
  }
  if (Array.isArray(record['watches'])) {
    result.watchCount = record['watches'].length;
  }
  return result;
}
