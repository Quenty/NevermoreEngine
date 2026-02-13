import { BatchTestResult } from './batch-test-runner.js';
import { formatDurationMs } from '../nevermore-cli-utils.js';

export const COMMENT_MARKER = '<!-- nevermore-test-results -->';

export interface TestCommentRow {
  packageName: string;
  status: string;
  error: string;
  placeId: number;
}

/**
 * Render a test results comment from pre-formatted rows and a footer line.
 */
export function formatTestComment(rows: TestCommentRow[], footer: string): string {
  const hasErrors = rows.some((r) => r.error.length > 0);
  const actionsRunUrl = getActionsRunUrl();

  let body = COMMENT_MARKER + '\n';
  body += '## Test Results\n\n';

  if (hasErrors) {
    body += '| Package | Status | Error | Try it |\n';
    body += '|---------|--------|-------|--------|\n';
  } else {
    body += '| Package | Status | Try it |\n';
    body += '|---------|--------|--------|\n';
  }

  for (const row of rows) {
    const link = `[Open in Roblox](https://www.roblox.com/games/${row.placeId})`;

    if (hasErrors) {
      body += `| ${row.packageName} | ${row.status} | ${row.error} | ${link} |\n`;
    } else {
      body += `| ${row.packageName} | ${row.status} | ${link} |\n`;
    }
  }

  body += '\n';
  body += footer;

  if (actionsRunUrl) {
    body += ` · [View logs](${actionsRunUrl})`;
  }

  body += '\n';
  return body;
}

export function formatResultStatus(pkg: BatchTestResult): string {
  const duration = formatDurationMs(pkg.durationMs);
  return pkg.success ? `✅ Passed (${duration})` : `❌ **Failed** (${duration})`;
}

export function formatErrorSummary(pkg: BatchTestResult): string {
  if (pkg.success) {
    return '';
  }

  if (pkg.error) {
    return _summarizeError(pkg.error);
  }

  return 'Test failed';
}

function _summarizeError(error: string): string {
  const firstLine = error.split('\n')[0];

  // Try to extract JSON error body from API responses
  // Format: "Action failed: STATUS TEXT: {json}"
  const jsonMatch = firstLine.match(/^(.+?failed): (\d{3}) \w+: (.+)$/);
  if (jsonMatch) {
    const [, action, status, jsonBody] = jsonMatch;
    const message = _extractJsonMessage(jsonBody);
    if (message) {
      return `${action} (${status}): ${message}`;
    }
  }

  if (firstLine.length > 80) {
    return firstLine.slice(0, 77) + '...';
  }
  return firstLine;
}

function _extractJsonMessage(text: string): string | undefined {
  try {
    const parsed = JSON.parse(text);
    if (Array.isArray(parsed.errors) && parsed.errors[0]?.message) {
      return parsed.errors[0].message;
    }
    if (typeof parsed.message === 'string') {
      return parsed.message;
    }
  } catch {
    // Not JSON
  }
  return undefined;
}

export function getActionsRunUrl(): string | undefined {
  const serverUrl = process.env.GITHUB_SERVER_URL;
  const repository = process.env.GITHUB_REPOSITORY;
  const runId = process.env.GITHUB_RUN_ID;

  if (serverUrl && repository && runId) {
    return `${serverUrl}/${repository}/actions/runs/${runId}`;
  }

  return undefined;
}
