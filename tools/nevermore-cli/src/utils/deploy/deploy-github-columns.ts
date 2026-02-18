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

/** Shared config for the deploy results GitHub comment reporter. */
export function createDeployCommentConfig(): GithubCommentTableConfig {
  return {
    heading: 'Deploy Results',
    commentMarker: '<!-- nevermore-deploy-results -->',
    extraColumns: [createErrorColumn(), createTryItColumn()],
    errorHeading: 'Deploy Results',
    successLabel: 'Deployed',
    failureLabel: 'Failed',
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
      return placeId
        ? `[Open in Roblox](https://www.roblox.com/games/${placeId})`
        : '';
    },
  };
}
