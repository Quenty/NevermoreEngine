import {
  type GithubCommentColumn,
  type GithubCommentTableConfig,
  type PackageResult,
  type PackageState,
  summarizeError,
} from '@quenty/cli-output-helpers/reporting';

/** Deploy-specific result that extends the generic PackageResult with placeId. */
export interface BatchDeployResult extends PackageResult {
  placeId: number;
}

/**
 * Shared config for the deploy results GitHub comment reporter.
 *
 * Takes the labels rather than fixing them, because a publish and a deploy are
 * different words and the command already knows which it is doing. Without
 * this the comment said "Failed" for a run whose terminal output said "DEPLOY
 * FAILED" — the same run, described two ways.
 */
export function createDeployCommentConfig(labels?: {
  successLabel?: string;
  failureLabel?: string;
}): GithubCommentTableConfig {
  return {
    heading: 'Deploy Results',
    commentMarker: '<!-- nevermore-deploy-results -->',
    sectionId: 'deploy',
    extraColumns: [createErrorColumn(), createTryItColumn()],
    errorHeading: 'Deploy Results',
    successLabel: labels?.successLabel ?? 'Deployed',
    failureLabel: labels?.failureLabel ?? 'DEPLOY FAILED',
    summaryVerb: 'deployed',
  };
}

function createErrorColumn(): GithubCommentColumn {
  return {
    header: 'Error',
    visibility: 'auto',
    render(pkg: PackageState) {
      if (!pkg.result || pkg.result.success) {
        return '';
      }
      if (pkg.result.error) {
        return summarizeError(pkg.result.error);
      }
      return 'Deploy failed';
    },
  };
}

function createTryItColumn(): GithubCommentColumn {
  return {
    header: 'Try it',
    render(pkg: PackageState) {
      const placeId =
        (pkg.result as BatchDeployResult | undefined)?.placeId ?? 0;
      if (!placeId) {
        return '';
      }
      const openUrl = `https://www.roblox.com/games/${placeId}`;
      const playUrl = `https://www.roblox.com/games/start?placeId=${placeId}`;
      return `[Open](${openUrl}) \\| [Play](${playUrl})`;
    },
  };
}
