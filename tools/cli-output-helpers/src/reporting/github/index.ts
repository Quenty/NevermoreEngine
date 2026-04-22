// Shared formatting types and helpers
export {
  type GithubCommentColumn,
  type GithubCommentTableConfig,
  type GithubTableRow,
  summarizeError,
  formatGithubTable,
  formatResultStatus,
  formatRunningStatus,
  getActionsRunUrl,
  formatGithubTableBody,
  formatGithubNoTestsBody,
  formatGithubErrorBody,
} from './formatting.js';

// PR comment reporter
export { GithubCommentTableReporter } from './comment-table-reporter.js';

// Job summary reporter
export { GithubJobSummaryReporter } from './job-summary-reporter.js';

// Workflow annotations
export {
  type DiagnosticSeverity,
  type Diagnostic,
  type DiagnosticSummary,
  formatAnnotation,
  emitAnnotations,
  summarizeDiagnostics,
  formatAnnotationSummaryMarkdown,
  writeAnnotationSummaryAsync,
} from './annotations.js';
