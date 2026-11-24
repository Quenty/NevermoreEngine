import { OutputHelper } from '@quenty/cli-output-helpers';

/** Pull the human-readable message out of an Open Cloud error body. */
export function extractApiMessage(body: string): string {
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

/**
 * A 401/403 from an Open Cloud place route, rendered with the scope it needed
 * and where to fix the key. Most failures here are a key missing one scope.
 */
export function formatAuthError(
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
  const apiMessage = extractApiMessage(body);

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
