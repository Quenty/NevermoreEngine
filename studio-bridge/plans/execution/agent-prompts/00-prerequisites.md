# Phase 0: Prerequisites -- Agent Prompts

**Phase reference**: [studio-bridge/plans/execution/phases/00-prerequisites.md](../phases/00-prerequisites.md)

## Overview

Phase 0 tasks (0.1-0.4) are fully specified in the standalone detailed design document. There are no separate agent prompts for these tasks.

See [studio-bridge/plans/execution/output-modes-plan.md](../output-modes-plan.md) for complete task specifications, acceptance criteria, and test plans.

**Task prerequisites**:
- **Tasks 0.1, 0.2, 0.3**: None (independent, can run in parallel).
- **Task 0.4** (barrel export + output mode selector): Tasks 0.1, 0.2, and 0.3 must be completed first.

## Conventions Reference

The following conventions apply to all agent prompts across all phases:

- **TypeScript ESM** with `.js` extensions on all local imports (e.g., `import { Foo } from './foo.js';`)
- **`Async` suffix** on all async functions (e.g., `listSessionsAsync`, `resolveRequestAsync`)
- **Private `_` prefix** on all private fields and methods
- **vitest** for tests: `describe`/`it`/`expect`, test files named `*.test.ts` alongside source
- **No default exports** -- always use named exports
- **yargs `CommandModule` pattern** for CLI commands (class with `command`, `describe`, `builder`, `handler`)
- **`@quenty/` scoped packages** for workspace imports (e.g., `@quenty/cli-output-helpers`)
- **`OutputHelper`** from `@quenty/cli-output-helpers` for all user-facing output

## Testing Conventions

The following conventions are **mandatory** for all test files across all phases. Violations will cause test gate failures.

### Fake timers for timing-sensitive tests

- ALL timing-sensitive tests MUST use `vi.useFakeTimers()`. This includes any test that involves timeouts, delays, reconnection windows, heartbeat intervals, jitter, grace periods, or any form of scheduled behavior.
- NO wall-clock timing assertions are permitted. Do not assert that something "completes within N seconds" or "takes less than N milliseconds" using `Date.now()` or `performance.now()`. These assertions are non-deterministic and will flake in CI.
- Use `vi.advanceTimersByTime(ms)` to deterministically advance time. For example, to test a 5-second timeout, call `vi.advanceTimersByTime(5000)` instead of waiting 5 real seconds.
- Restore real timers in `afterEach` to prevent leaking fake timer state between tests:
  ```typescript
  afterEach(() => {
    vi.useRealTimers();
  });
  ```
- When using fake timers with async code, remember to `await` any pending promises after advancing time. Use `vi.advanceTimersByTimeAsync(ms)` when the timer callbacks themselves are async.

### Shared MockPluginClient

- All tests that connect a mock plugin MUST use the standardized `MockPluginClient` defined in [shared-test-utilities.md](../validation/shared-test-utilities.md). Do not create ad-hoc WebSocket clients or raw WebSocket mocks for plugin simulation.
- Import from `../test-utils/mock-plugin-client.js` (relative to the test file's location within `tools/studio-bridge/src/`).
- See the shared utilities spec for the full interface, configuration options, and usage examples.

### Example: timing-sensitive test pattern

```typescript
import { MockPluginClient } from "../test-utils/mock-plugin-client.js";

describe("failover", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("client takes over after host disconnect", async () => {
    vi.useFakeTimers();

    const mock = new MockPluginClient({ port: server.port });
    await mock.connectAsync();

    // Kill the host
    await host.disconnectAsync();

    // Advance past the jitter + takeover window
    await vi.advanceTimersByTimeAsync(2000);

    expect(client.role).toBe("host");

    // Advance past plugin reconnection window
    await vi.advanceTimersByTimeAsync(5000);

    expect(mock.isConnected).toBe(true);
    await mock.disconnectAsync();
  });
});
```

## Cross-References

- Phase plan: [studio-bridge/plans/execution/phases/00-prerequisites.md](../phases/00-prerequisites.md)
- Detailed design: [studio-bridge/plans/execution/output-modes-plan.md](../output-modes-plan.md)
- Shared test utilities: [studio-bridge/plans/execution/validation/shared-test-utilities.md](../validation/shared-test-utilities.md)
- Note: Phase 0 has no separate validation file; tests are specified in `studio-bridge/plans/execution/output-modes-plan.md`.
