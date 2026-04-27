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
} from './reporter.js';

// Single-result reporter — for one-shot or polled command output.
export { BaseResultReporter, type ResultReporter } from './result-reporter.js';
export {
  StdoutResultReporter,
  type StdoutResultReporterOptions,
} from './stdout-result-reporter.js';
export {
  FileResultReporter,
  type FileResultReporterOptions,
} from './file-result-reporter.js';
export {
  WatchResultReporter,
  type WatchResultReporterOptions,
} from './watch-result-reporter.js';
export { CompositeResultReporter } from './composite-result-reporter.js';

// Output formatting primitives.
export {
  formatTable,
  type TableColumn,
  type TableOptions,
} from './format-table.js';
export { formatJson, type JsonOutputOptions } from './format-json.js';
export {
  createWatchRenderer,
  type WatchRenderer,
  type WatchRendererOptions,
} from './watch-renderer.js';
export { resolveOutputMode, type OutputMode } from './output-mode.js';

// Progress formatting helpers
export {
  formatProgressInline,
  formatProgressResult,
  isEmptyTestRun,
  summarizeFailure,
} from './progress-format.js';

// State tracking
export {
  type IStateTracker,
  type PackageState,
} from './state/state-tracker.js';
export { LiveStateTracker } from './state/live-state-tracker.js';
export { LoadedStateTracker } from './state/loaded-state-tracker.js';

// Reporter implementations
export { CompositeReporter } from './composite-reporter.js';
export {
  SimpleReporter,
  type SimpleReporterOptions,
} from './simple-reporter.js';
export {
  SpinnerReporter,
  type SpinnerReporterOptions,
} from './spinner-reporter.js';
export {
  GroupedReporter,
  type GroupedReporterOptions,
} from './grouped-reporter.js';
export {
  SummaryTableReporter,
  type SummaryTableReporterOptions,
} from './summary-table-reporter.js';
export { JsonFileReporter } from './json-file-reporter.js';
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
  emitAnnotations,
  summarizeDiagnostics,
  formatAnnotationSummaryMarkdown,
  writeAnnotationSummaryAsync,
} from './github/index.js';
