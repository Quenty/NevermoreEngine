# Test Reporting

Lifecycle-based reporting system for test execution. Reporters receive hooks as tests progress and render output in different formats.

## Architecture

```
CompositeTestReporter
  owns LiveTestStateTracker (centralized state)
  fans out to child reporters:
    SpinnerTestReporter      TTY spinner grid
    GroupedTestReporter       CI / verbose grouped output
    SimpleTestReporter        Single-package inline output
    SummaryTableTestReporter  Final results table
    JsonFileTestReporter      Writes results JSON to disk
    GithubCommentTestReporter Live-updating PR comment
```

### Lifecycle

All reporters implement `TestReporter` via `BaseTestReporter` (no-op defaults):

1. `startAsync()` — before any tests run
2. `onPackageStart(name)` — a package begins testing
3. `onPackagePhaseChange(name, phase)` — phase transition (building, uploading, scheduling, executing)
4. `onPackageResult(result)` — a package completes
5. `stopAsync()` — after all tests complete

### State tracking

`CompositeTestReporter` owns a `LiveTestStateTracker` and updates it before fanning out to child reporters. Reporters read state via the `ITestStateTracker` interface — they never manage their own state maps.

`LoadedTestStateTracker` implements the same interface from a saved JSON file, used for post-hoc reporting (e.g. `nevermore ci post-test-results`).

### Usage

```typescript
const reporter = new CompositeTestReporter(packageNames, (state) => [
  new SpinnerTestReporter(state, { showLogs }),
  new GithubCommentTestReporter(state, concurrency),
]);

await reporter.startAsync();
// ... run tests, which call reporter.onPackageStart/onPackagePhaseChange/onPackageResult ...
await reporter.stopAsync();
```
