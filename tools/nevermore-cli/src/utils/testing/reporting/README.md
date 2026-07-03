# Test Reporting

Test-specific reporting layer built on the generic batch job reporting framework from `@quenty/cli-output-helpers/reporting`.

## Architecture

```
CompositeReporter
  owns LiveStateTracker (centralized state)
  fans out to child reporters:
    SpinnerReporter            TTY spinner grid
    GroupedReporter             CI / verbose grouped output
    SimpleReporter              Single-package inline output
    SummaryTableReporter        Final results table
    JsonFileReporter            Writes results JSON to disk
    GithubCommentTableReporter  Live-updating PR comment (with test columns)
```

### Generic framework (`@quenty/cli-output-helpers/reporting`)

All reporters implement `Reporter` via `BaseReporter` (no-op defaults):

1. `startAsync()` — before any jobs run
2. `onPackageStart(name)` — a package begins processing
3. `onPackagePhaseChange(name, phase)` — phase transition (building, uploading, scheduling, executing)
4. `onPackageResult(result)` — a package completes
5. `stopAsync()` — after all jobs complete

### Test-specific layer (this directory)

- `test-types.ts` — `BatchTestResult` extends `PackageResult` with `placeId`
- `test-github-columns.ts` — Error and "Try it" column factories for GitHub comment tables
- `index.ts` — re-exports everything from the generic framework plus test-specific types

### State tracking

`CompositeReporter` owns a `LiveStateTracker` and updates it before fanning out to child reporters. Reporters read state via the `IStateTracker` interface — they never manage their own state maps.

`LoadedStateTracker` implements the same interface from a saved JSON file, used for post-hoc reporting (e.g. `nevermore ci post-test-results`).

### Usage

```typescript
import {
  CompositeReporter,
  SpinnerReporter,
  GithubCommentTableReporter,
  createTestColumns,
} from './reporting/index.js';

const reporter = new CompositeReporter(packageNames, (state) => [
  new SpinnerReporter(state, { showLogs, actionVerb: 'Testing' }),
  new GithubCommentTableReporter(state, {
    heading: 'Test Results',
    commentMarker: '<!-- nevermore-test-results -->',
    extraColumns: createTestColumns(),
  }, concurrency),
]);

await reporter.startAsync();
// ... run tests, which call reporter.onPackageStart/onPackagePhaseChange/onPackageResult ...
await reporter.stopAsync();
```
