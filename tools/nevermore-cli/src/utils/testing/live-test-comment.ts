import { BatchTestResult, type TestPhase } from './batch-test-runner.js';
import { TestablePackage } from './changed-tests-utils.js';
import { formatDurationMs } from '../nevermore-cli-utils.js';
import {
  formatTestComment,
  formatResultStatus,
  formatErrorSummary,
  type TestCommentRow,
} from './github-comment-formatting.js';
import { postOrUpdateCommentAsync } from './github-comment.js';

type PackageStatus =
  | { state: 'pending' }
  | { state: 'running'; phase?: TestPhase }
  | { state: 'done'; result: BatchTestResult };

/**
 * Maintains a live PR comment that updates as tests progress.
 * The table grid is stable — same rows throughout, only status changes.
 * Updates are throttled to avoid GitHub API rate limits.
 */
export class LiveTestComment {
  private _packages: Map<string, { pkg: TestablePackage; status: PackageStatus }>;
  private _startTimeMs: number;
  private _concurrency: number;
  private _updateTimer: ReturnType<typeof setTimeout> | undefined;
  private _updatePending = false;
  private _disposed = false;
  private _enabled: boolean;

  private static readonly THROTTLE_MS = 10_000;

  constructor(packages: TestablePackage[], concurrency: number) {
    this._packages = new Map();
    this._startTimeMs = Date.now();
    this._concurrency = concurrency;

    for (const pkg of packages) {
      this._packages.set(pkg.name, { pkg, status: { state: 'pending' } });
    }

    // Only enable live updates in GitHub Actions with GITHUB_TOKEN
    this._enabled = !!process.env.GITHUB_ACTIONS && !!process.env.GITHUB_TOKEN;
  }

  async postInitialAsync(): Promise<void> {
    if (!this._enabled) return;
    await this._postUpdateAsync();
  }

  markRunning(packageName: string): void {
    const entry = this._packages.get(packageName);
    if (entry) {
      entry.status = { state: 'running' };
      this._scheduleUpdate();
    }
  }

  markPhase(packageName: string, phase: TestPhase): void {
    const entry = this._packages.get(packageName);
    if (entry && entry.status.state === 'running') {
      entry.status = { state: 'running', phase };
      this._scheduleUpdate();
    }
  }

  markComplete(result: BatchTestResult): void {
    const entry = this._packages.get(result.packageName);
    if (entry) {
      entry.status = { state: 'done', result };
      this._scheduleUpdate();
    }
  }

  async flushAsync(): Promise<void> {
    this._disposed = true;
    if (this._updateTimer) {
      clearTimeout(this._updateTimer);
      this._updateTimer = undefined;
    }
    if (this._enabled) {
      await this._postUpdateAsync();
    }
  }

  private _scheduleUpdate(): void {
    if (!this._enabled || this._disposed) return;
    if (this._updateTimer) {
      this._updatePending = true;
      return;
    }

    this._updateTimer = setTimeout(async () => {
      await this._postUpdateAsync();
      this._updateTimer = undefined;

      if (this._updatePending && !this._disposed) {
        this._updatePending = false;
        this._scheduleUpdate();
      }
    }, LiveTestComment.THROTTLE_MS);
    this._updateTimer.unref();
  }

  private async _postUpdateAsync(): Promise<void> {
    const body = this._formatBody();
    await postOrUpdateCommentAsync(body);
  }

  /**
   * Compute average duration of completed packages, or undefined if none finished yet.
   */
  private _getAvgDurationMs(): number | undefined {
    const entries = [...this._packages.values()];
    const done = entries.filter((e) => e.status.state === 'done') as Array<{
      pkg: TestablePackage;
      status: { state: 'done'; result: BatchTestResult };
    }>;

    if (done.length === 0) return undefined;
    const totalMs = done.reduce((sum, e) => sum + e.status.result.durationMs, 0);
    return totalMs / done.length;
  }

  private _formatPendingStatus(queueIndex: number, totalPending: number): string {
    const avgMs = this._getAvgDurationMs();

    if (avgMs !== undefined) {
      const roundsAhead = Math.floor(queueIndex / this._concurrency);
      const etaMs = avgMs * (roundsAhead + 1);
      return `⏳ Pending (${queueIndex + 1}/${totalPending} in ~${formatDurationMs(etaMs)})`;
    }

    return `⏳ Pending (${queueIndex + 1}/${totalPending})`;
  }

  private _formatBody(): string {
    const entries = [...this._packages.values()];
    const allDone = entries.every((e) => e.status.state === 'done');
    const elapsedMs = Date.now() - this._startTimeMs;

    let pendingIndex = 0;
    const totalPending = entries.filter((e) => e.status.state === 'pending').length;

    const rows: TestCommentRow[] = entries.map(({ pkg, status }) => {
      let statusText: string;
      let error = '';

      switch (status.state) {
        case 'pending':
          statusText = this._formatPendingStatus(pendingIndex++, totalPending);
          break;
        case 'running':
          statusText = _formatRunningStatus(status.phase);
          break;
        case 'done':
          statusText = formatResultStatus(status.result);
          error = formatErrorSummary(status.result);
          break;
      }

      return {
        packageName: pkg.name,
        status: statusText,
        error,
        placeId: pkg.target.placeId,
      };
    });

    let footer: string;
    if (allDone) {
      const passed = entries.filter((e) => e.status.state === 'done' && e.status.result.success).length;
      const failed = entries.filter((e) => e.status.state === 'done' && !e.status.result.success).length;
      footer = `**${entries.length} tested, ${passed} passed, ${failed} failed** in ${formatDurationMs(elapsedMs)}`;
    } else {
      const done = entries.filter((e) => e.status.state === 'done').length;
      const running = entries.filter((e) => e.status.state === 'running').length;
      const pending = entries.filter((e) => e.status.state === 'pending').length;
      const parts: string[] = [];
      if (done > 0) parts.push(`${done} done`);
      if (running > 0) parts.push(`${running} running`);
      if (pending > 0) parts.push(`${pending} pending`);
      footer = `**${entries.length} packages** · ${parts.join(', ')}`;
    }

    return formatTestComment(rows, footer);
  }
}

function _formatRunningStatus(phase?: TestPhase): string {
  switch (phase) {
    case 'building': return '🔨 Building...';
    case 'uploading': return '📤 Uploading...';
    case 'scheduling': return '⏳ Scheduling...';
    case 'executing': return '🔄 Executing...';
    default: return '🔄 Running...';
  }
}
