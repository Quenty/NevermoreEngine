import {
  type GithubCommentColumn,
  type GithubCommentTableConfig,
  type PackageState,
  summarizeError,
} from '@quenty/cli-output-helpers/reporting';
import { type BatchTestResult } from './test-types.js';

/** Create the extra GitHub comment columns used by the test reporter. */
export function createTestColumns(): GithubCommentColumn[] {
  return [createErrorColumn(), createTryItColumn()];
}

/** Shared config for the test results GitHub comment reporter. */
export function createTestCommentConfig(): GithubCommentTableConfig {
  return {
    heading: 'Test Results',
    commentMarker: '<!-- nevermore-test-results -->',
    extraColumns: createTestColumns(),
    errorHeading: 'Test Results',
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
      return 'Test failed';
    },
  };
}

function createTryItColumn(): GithubCommentColumn {
  return {
    header: 'Try it',
    render(pkg: PackageState) {
      const placeId =
        (pkg.result as BatchTestResult | undefined)?.placeId ?? 0;
      return placeId
        ? `[Open in Roblox](https://www.roblox.com/games/${placeId})`
        : '';
    },
  };
}
