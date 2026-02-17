import {
  type GithubCommentColumn,
  type GithubCommentTableConfig,
  type PackageState,
  summarizeError,
} from '@quenty/cli-output-helpers/reporting';

/** Shared config for the deploy results GitHub comment reporter. */
export function createDeployCommentConfig(): GithubCommentTableConfig {
  return {
    heading: 'Deploy Results',
    commentMarker: '<!-- nevermore-deploy-results -->',
    extraColumns: [createErrorColumn()],
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
