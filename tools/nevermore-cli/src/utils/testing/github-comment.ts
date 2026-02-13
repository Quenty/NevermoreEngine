import * as fsSync from 'fs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { BatchTestSummary } from './batch-test-runner.js';

const COMMENT_MARKER = '<!-- nevermore-test-results -->';

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

  // PR number from GITHUB_REF_NAME (e.g. "123/merge") or GITHUB_EVENT_PATH
  let prNumber: number | undefined;

  const refName = process.env.GITHUB_REF_NAME;
  if (refName) {
    const match = refName.match(/^(\d+)\/merge$/);
    if (match) {
      prNumber = parseInt(match[1], 10);
    }
  }

  if (!prNumber) {
    // Try event payload
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

function _formatCommentBody(results: BatchTestSummary): string {
  let body = COMMENT_MARKER + '\n';
  body += '## Test Results\n\n';
  body += '| Package | Status | Try it |\n';
  body += '|---------|--------|--------|\n';

  for (const pkg of results.packages) {
    const status = pkg.success ? 'Passed' : '**Failed**';
    const link = `[Open in Roblox](https://www.roblox.com/games/${pkg.placeId})`;
    body += `| ${pkg.packageName} | ${status} | ${link} |\n`;
  }

  body += `\n**${results.summary.total} tested, ${results.summary.passed} passed, ${results.summary.failed} failed**\n`;
  return body;
}

/**
 * Post or update a PR comment with test results.
 * Requires GITHUB_TOKEN, GITHUB_REPOSITORY, and PR number (from GITHUB_REF_NAME or event payload).
 * Returns true if the comment was posted, false if context was unavailable.
 */
export async function postTestResultsCommentAsync(
  results: BatchTestSummary
): Promise<boolean> {
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

  const body = _formatCommentBody(results);

  // Find existing comment with our marker
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
