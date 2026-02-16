// Re-export generic reporting framework
export {
  BaseReporter,
  type Reporter,
  type JobPhase,
  type PackageStatus,
  type PackageResult,
  type BatchSummary,
  type IStateTracker,
  type PackageState,
  LiveStateTracker,
  LoadedStateTracker,
  CompositeReporter,
  SimpleReporter,
  type SimpleReporterOptions,
  SpinnerReporter,
  type SpinnerReporterOptions,
  GroupedReporter,
  type GroupedReporterOptions,
  SummaryTableReporter,
  JsonFileReporter,
  GithubCommentTableReporter,
  type GithubCommentColumn,
  type GithubCommentTableConfig,
  summarizeError,
} from '@quenty/cli-output-helpers/reporting';

// Test-specific types
export { type BatchTestResult, type BatchTestSummary } from './test-types.js';

// Test-specific GitHub columns and config
export { createTestColumns, createTestCommentConfig } from './test-github-columns.js';

// Backward-compatible aliases
export {
  type Reporter as TestReporter,
  type JobPhase as TestPhase,
  type PackageStatus as PackageTestStatus,
} from '@quenty/cli-output-helpers/reporting';
