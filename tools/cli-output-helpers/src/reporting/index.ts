// Core types and base class — batch lifecycle (multi-package, phases, progress).
export {
  BaseReporter,
  type Reporter,
  type JobPhase,
  type PackageStatus,
  type PackageResult,
  type BatchSummary,
  type ProgressSummary,
  type TestCountProgress,
  type ByteProgress,
  type StepProgress,
} from './batch/reporter.js';

// Single-result reporter — for one-shot or polled command output.
export {
  BaseResultReporter,
  type ResultReporter,
} from './result/result-reporter.js';
export {
  StdoutResultReporter,
  type StdoutResultReporterOptions,
} from './result/stdout-result-reporter.js';
export {
  FileResultReporter,
  type FileResultReporterOptions,
} from './result/file-result-reporter.js';
export {
  WatchResultReporter,
  type WatchResultReporterOptions,
} from './result/watch-result-reporter.js';
export { AggregatedBatchReporter } from './batch/aggregated-batch-reporter.js';
export {
  DirectoryResultReporter,
  type DirectoryResultReporterOptions,
  type OutputFile,
} from './result/directory-result-reporter.js';
export { CompositeResultReporter } from './result/composite-result-reporter.js';
export {
  buildResultReporter,
  type BuildResultReporterOptions,
} from './result/build-result-reporter.js';

// Output formatting primitives.
export {
  formatTable,
  type TableColumn,
  type TableOptions,
} from './format/format-table.js';
export {
  formatTree,
  type TreeNode,
  type TreeOptions,
} from './format/format-tree.js';
export { formatCount } from './format/format-count.js';
export { formatJson, type JsonOutputOptions } from './format/format-json.js';
export { formatCsv, toCsvField, type CsvValue } from './format/format-csv.js';
export {
  createWatchRenderer,
  type WatchRenderer,
  type WatchRendererOptions,
} from './result/watch-renderer.js';

// Progress formatting helpers
export {
  formatProgressInline,
  formatProgressResult,
  isEmptyTestRun,
  summarizeFailure,
} from './format/progress-format.js';
export {
  colorStatus,
  formatStatusText,
  resolveResultStatus,
  statusIcon,
  tallyCaveats,
  type ResolveResultStatusOptions,
  type ResultCaveat,
  type ResultSeverity,
  type ResultStatus,
  type ResultStatusInput,
} from './batch/result-status.js';

// State tracking
export {
  type IStateTracker,
  type PackageState,
} from './batch/state/state-tracker.js';
export { LiveStateTracker } from './batch/state/live-state-tracker.js';
export { LoadedStateTracker } from './batch/state/loaded-state-tracker.js';

// Reporter implementations
export { CompositeReporter } from './batch/composite-reporter.js';
export {
  SimpleReporter,
  type SimpleReporterOptions,
} from './batch/simple-reporter.js';
export {
  SpinnerReporter,
  type SpinnerReporterOptions,
} from './batch/spinner-reporter.js';
export {
  GroupedReporter,
  type GroupedReporterOptions,
} from './batch/grouped-reporter.js';
export {
  SummaryTableReporter,
  type SummaryTableReporterOptions,
} from './batch/summary-table-reporter.js';
export { JsonFileReporter } from './batch/json-file-reporter.js';
export {
  GithubCommentTableReporter,
  GithubJobSummaryReporter,
  type GithubCommentColumn,
  type GithubCommentTableConfig,
  type GithubTableRow,
  summarizeError,
  type DiagnosticSeverity,
  type Diagnostic,
  type DiagnosticSummary,
  formatAnnotation,
  dedupeDiagnostics,
  emitAnnotations,
  summarizeDiagnostics,
  formatAnnotationSummaryMarkdown,
  writeAnnotationSummaryAsync,
} from './github/index.js';
