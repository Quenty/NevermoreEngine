/**
 * GitHub API helpers for posting and updating PR comments.
 */

import * as fsSync from 'fs';
import { OutputHelper } from '../../outputHelper.js';

/** Shared marker used for the combined CI results comment. */
export const SHARED_CI_COMMENT_MARKER = '<!-- nevermore-ci-results -->';

interface GitHubContext {
  token: string;
  owner: string;
  repo: string;
  prNumber: number;
}

/**
 * Resolve GitHub context from environment variables.
 *
 * Reads GITHUB_TOKEN, GITHUB_REPOSITORY, and determines the PR number
 * from GITHUB_REF_NAME (e.g. "123/merge") or the event payload at
 * GITHUB_EVENT_PATH.
 */
export function resolveGitHubContext(): GitHubContext | undefined {
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
        const event = JSON.parse(fsSync.readFileSync(eventPath, 'utf-8'));
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

/**
 * Post or update a PR comment identified by a marker string.
 *
 * Searches existing comments for one containing `commentMarker`.
 * If found, updates it via PATCH; otherwise creates a new comment.
 * Returns false and warns (rather than throwing) on failure.
 */
export async function postOrUpdateCommentAsync(
  commentMarker: string,
  body: string
): Promise<boolean> {
  const ctx = resolveGitHubContext();
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
  const existing = comments.find((c) => c.body.includes(commentMarker));

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

    OutputHelper.info('Updated PR comment with results.');
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

    OutputHelper.info('Posted PR comment with results.');
  }

  return true;
}

/**
 * Post or update a section within a shared PR comment.
 *
 * Uses {@link SHARED_CI_COMMENT_MARKER} to find the combined comment, then
 * replaces the section delimited by `<!-- section:ID -->` / `<!-- /section:ID -->`.
 * If the section doesn't exist yet, appends it. If no combined comment exists,
 * creates one.
 */
export async function postOrUpdateCommentSectionAsync(
  sectionId: string,
  sectionBody: string
): Promise<boolean> {
  const ctx = resolveGitHubContext();
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

  const sectionStart = `<!-- section:${sectionId} -->`;
  const sectionEnd = `<!-- /section:${sectionId} -->`;
  const wrappedSection = `${sectionStart}\n${sectionBody}\n${sectionEnd}`;

  const existing = comments.find((c) =>
    c.body.includes(SHARED_CI_COMMENT_MARKER)
  );

  let fullBody: string;
  if (existing) {
    const startIdx = existing.body.indexOf(sectionStart);
    const endIdx = existing.body.indexOf(sectionEnd);

    if (startIdx >= 0 && endIdx >= 0) {
      // Replace existing section
      fullBody =
        existing.body.slice(0, startIdx) +
        wrappedSection +
        existing.body.slice(endIdx + sectionEnd.length);
    } else {
      // Append new section
      fullBody = existing.body.trimEnd() + '\n\n' + wrappedSection + '\n';
    }

    const updateResponse = await fetch(
      `${apiBase}/issues/comments/${existing.id}`,
      {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ body: fullBody }),
      }
    );

    if (!updateResponse.ok) {
      OutputHelper.warn(
        `Failed to update PR comment: ${updateResponse.status} ${updateResponse.statusText}`
      );
      return false;
    }

    OutputHelper.info(`Updated PR comment (section: ${sectionId}).`);
  } else {
    fullBody = SHARED_CI_COMMENT_MARKER + '\n\n' + wrappedSection + '\n';

    const createResponse = await fetch(
      `${apiBase}/issues/${ctx.prNumber}/comments`,
      {
        method: 'POST',
        headers,
        body: JSON.stringify({ body: fullBody }),
      }
    );

    if (!createResponse.ok) {
      OutputHelper.warn(
        `Failed to create PR comment: ${createResponse.status} ${createResponse.statusText}`
      );
      return false;
    }

    OutputHelper.info(`Posted PR comment (section: ${sectionId}).`);
  }

  return true;
}
