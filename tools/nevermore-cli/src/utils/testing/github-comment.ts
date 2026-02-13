import * as fsSync from 'fs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { BatchTestSummary } from './batch-test-runner.js';
import { formatDurationMs } from '../nevermore-cli-utils.js';
import {
  COMMENT_MARKER,
  formatTestComment,
  formatResultStatus,
  formatErrorSummary,
  getActionsRunUrl,
  type TestCommentRow,
} from './github-comment-formatting.js';

export {
  COMMENT_MARKER,
  formatTestComment,
  formatResultStatus,
  formatErrorSummary,
  getActionsRunUrl,
  type TestCommentRow,
} from './github-comment-formatting.js';

// ── GitHub context + API ────────────────────────────────────────────────────

interface GitHubContext {
  token: string;
  owner: string;
  repo: string;
  prNumber: number;
}

function _resolveGitHubContext(): GitHubContext | undefined {
  const token = process.env.GITHUB_TOKEN;
  const repository = process.env.GITHUB_REPOSITORY;

  if (!token || !repository) {
    return undefined;
  }

  const [owner, repo] = repository.split('/');
  if (!owner || !repo) {
    return undefined;
  }

  let prNumber: number | undefined;

  const refName = process.env.GITHUB_REF_NAME;
  if (refName) {
    const match = refName.match(/^(\d+)\/merge$/);
    if (match) {
      prNumber = parseInt(match[1], 10);
    }
  }

  if (!prNumber) {
    const eventPath = process.env.GITHUB_EVENT_PATH;
    if (eventPath) {
      try {
        const event = JSON.parse(
          fsSync.readFileSync(eventPath, 'utf-8')
        );
        prNumber = event?.pull_request?.number ?? event?.number;
      } catch {
        // ignore
      }
    }
  }

  if (!prNumber) {
    return undefined;
  }

  return { token, owner, repo, prNumber };
}

export async function postOrUpdateCommentAsync(body: string): Promise<boolean> {
  const ctx = _resolveGitHubContext();
  if (!ctx) {
    OutputHelper.warn(
      'GitHub context not available (missing GITHUB_TOKEN, GITHUB_REPOSITORY, or PR number). Skipping PR comment.'
    );
    return false;
  }

  const apiBase = `https://api.github.com/repos/${ctx.owner}/${ctx.repo}`;
  const headers = {
    Authorization: `Bearer ${ctx.token}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  };

  const listResponse = await fetch(
    `${apiBase}/issues/${ctx.prNumber}/comments?per_page=100`,
    { headers }
  );

  if (!listResponse.ok) {
    OutputHelper.warn(
      `Failed to list PR comments: ${listResponse.status} ${listResponse.statusText}`
    );
    return false;
  }

  const comments = (await listResponse.json()) as Array<{
    id: number;
    body: string;
  }>;
  const existing = comments.find((c) => c.body.includes(COMMENT_MARKER));

  if (existing) {
    const updateResponse = await fetch(
      `${apiBase}/issues/comments/${existing.id}`,
      {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ body }),
      }
    );

    if (!updateResponse.ok) {
      OutputHelper.warn(
        `Failed to update PR comment: ${updateResponse.status} ${updateResponse.statusText}`
      );
      return false;
    }

    OutputHelper.info('Updated PR comment with test results.');
  } else {
    const createResponse = await fetch(
      `${apiBase}/issues/${ctx.prNumber}/comments`,
      {
        method: 'POST',
        headers,
        body: JSON.stringify({ body }),
      }
    );

    if (!createResponse.ok) {
      OutputHelper.warn(
        `Failed to create PR comment: ${createResponse.status} ${createResponse.statusText}`
      );
      return false;
    }

    OutputHelper.info('Posted PR comment with test results.');
  }

  return true;
}

// ── High-level posting functions ────────────────────────────────────────────

export async function postTestResultsCommentAsync(
  results: BatchTestSummary
): Promise<boolean> {
  const rows: TestCommentRow[] = results.packages.map((pkg) => ({
    packageName: pkg.packageName,
    status: formatResultStatus(pkg),
    error: formatErrorSummary(pkg),
    placeId: pkg.placeId,
  }));

  const totalTime = formatDurationMs(results.summary.durationMs);
  const footer = `**${results.summary.total} tested, ${results.summary.passed} passed, ${results.summary.failed} failed** in ${totalTime}`;

  return postOrUpdateCommentAsync(formatTestComment(rows, footer));
}

export async function postTestRunFailedCommentAsync(
  error: string
): Promise<boolean> {
  const actionsRunUrl = getActionsRunUrl();

  let body = COMMENT_MARKER + '\n';
  body += '## Test Results\n\n';
  body += `❌ **Test run failed before producing results**\n\n`;
  body += `\`\`\`\n${error}\n\`\`\`\n`;

  if (actionsRunUrl) {
    body += `\n[View logs](${actionsRunUrl})\n`;
  }

  return postOrUpdateCommentAsync(body);
}
