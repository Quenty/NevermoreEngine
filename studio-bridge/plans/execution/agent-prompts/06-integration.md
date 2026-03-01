# Phase 6: Polish (Integration) -- Agent Prompts

**Phase reference**: [studio-bridge/plans/execution/phases/06-integration.md](../phases/06-integration.md)
**Validation**: [studio-bridge/plans/execution/validation/06-integration.md](../validation/06-integration.md)

Base path for all file references: `/workspaces/NevermoreEngine/tools/studio-bridge/`

## How to Use These Prompts

1. Copy the full prompt for a single task into a Claude Code sub-agent session.
2. The agent should read the "Read First" files, then implement the "Requirements" section.
3. The agent should run the acceptance criteria checks before reporting completion.
4. Do not give an agent a task whose dependencies have not been completed yet (see the dependency graph in [studio-bridge/plans/execution/phases/06-integration.md](../phases/06-integration.md)).

Key conventions that apply to every prompt:

- **TypeScript ESM** with `.js` extensions on all local imports (e.g., `import { Foo } from './foo.js';`)
- **`Async` suffix** on all async functions (e.g., `listSessionsAsync`, `resolveRequestAsync`)
- **Private `_` prefix** on all private fields and methods
- **vitest** for tests: `describe`/`it`/`expect`, test files named `*.test.ts` alongside source
- **No default exports** -- always use named exports
- **yargs `CommandModule` pattern** for CLI commands (class with `command`, `describe`, `builder`, `handler`)
- **`@quenty/` scoped packages** for workspace imports (e.g., `@quenty/cli-output-helpers`)
- **`OutputHelper`** from `@quenty/cli-output-helpers` for all user-facing output

---

## Task 6.4: Update index.ts Exports

**Prerequisites**: All phases (0-5) must be completed first. This task exports the public API surface from all prior phases.

**Context**: The library's public API is exported from `src/index.ts`. New types, classes, and functions added across all phases need to be exported for library consumers.

**Objective**: Update `src/index.ts` to export all new public types and classes.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/index.ts` (the file you will modify)
- Browse all new files created in Phases 1-5 to identify public exports.

**Files to Modify**:
- `src/index.ts`

**Requirements**:

1. Add exports for the registry module:

```typescript
export { BridgeConnection } from './server/bridge-connection.js';
export type { SessionInfo, SessionEvent, SessionOrigin, Disposable } from './registry/index.js';
```

2. Add exports for new protocol types:

```typescript
export type {
  StudioState,
  Capability,
  ErrorCode,
  SerializedValue,
  DataModelInstance,
  SubscribableEvent,
  RegisterMessage,
  StateResultMessage,
  ScreenshotResultMessage,
  DataModelResultMessage,
  LogsResultMessage,
  StateChangeMessage,
  HeartbeatMessage,
  SubscribeResultMessage,
  UnsubscribeResultMessage,
  PluginErrorMessage,
  QueryStateMessage,
  CaptureScreenshotMessage,
  QueryDataModelMessage,
  QueryLogsMessage,
  SubscribeMessage,
  UnsubscribeMessage,
  ServerErrorMessage,
} from './server/web-socket-protocol.js';
export { decodeServerMessage } from './server/web-socket-protocol.js';
```

3. Add exports for action wrappers (if they exist):

```typescript
export { queryStateAsync } from './server/actions/query-state.js';
export { queryLogsAsync } from './server/actions/query-logs.js';
// ... etc for each action wrapper that was created
```

4. Add exports for plugin discovery:

```typescript
export { isPersistentPluginInstalled } from './plugin/plugin-discovery.js';
```

5. Ensure all existing exports remain unchanged.

**Acceptance Criteria**:
- All new public types and functions are exported.
- All existing exports are preserved.
- `tsc --noEmit` passes from `tools/studio-bridge/`.

**Do NOT**:
- Remove any existing exports.
- Export internal/private types.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 6.5: CI Integration

**Prerequisites**: Task 4.3 (devcontainer auto-detection) must be completed first. Tasks 4.2, 4.3, and 6.5 all modify `bridge-connection.ts` and must be sequenced: 4.2 then 4.3 then 6.5.

**Context**: In CI environments (GitHub Actions, etc.), the persistent plugin is never installed. Session tracking is in-memory via the bridge host, so no directory configuration is needed for sessions.

**Objective**: Make plugin detection CI-aware.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/plugin/plugin-discovery.ts` (plugin detection to modify)

**Files to Modify**:
- `src/plugin/plugin-discovery.ts` -- return `false` for `isPersistentPluginInstalled()` in CI

**Requirements**:

1. In `plugin-discovery.ts`, update `isPersistentPluginInstalled`:

```typescript
export function isPersistentPluginInstalled(): boolean {
  if (process.env.CI === 'true') {
    return false;
  }
  return fs.existsSync(getPersistentPluginPath());
}
```

2. Add a test that verifies CI behavior by temporarily setting `process.env.CI`.

Note: Session tracking is entirely in-memory via the bridge host. There are no session files, directories, or environment variables for session storage. No CI-specific session configuration is needed.

**Acceptance Criteria**:
- In CI, `isPersistentPluginInstalled()` returns `false` regardless of file existence.
- Normal (non-CI) behavior is unchanged.

**Do NOT**:
- Change any constructor signatures in a breaking way.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 6.1: Update Existing Tests

**Prerequisites**: All of Phases 1-3 must be completed first.

**Context**: The refactoring across Phases 1-3 changed protocol types, server internals, handshake behavior, and the CLI command surface. Existing tests need to be verified and updated to cover the new behavior while ensuring no regressions.

**Objective**: Verify all existing tests pass, fix any that break due to Phase 1-3 changes, and add integration tests that exercise the new v2 behavior in the existing test files.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.test.ts` (primary test file to update)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.test.ts` (protocol test file -- should already have v2 tests from Task 1.1, verify coverage)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/pending-request-map.test.ts` (from Task 1.2 -- verify tests pass)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/action-dispatcher.test.ts` (from Task 1.6 -- verify tests pass)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/bridge-connection.test.ts` (from Tasks 1.3d1-1.3d4 -- verify tests pass)

**Files to Modify**:
- `src/server/studio-bridge-server.test.ts` -- add new test cases
- `src/server/web-socket-protocol.test.ts` -- verify coverage, add if needed

**Requirements**:

1. Run all existing tests first: `cd tools/studio-bridge && npx vitest run`. Fix any failures caused by Phase 1-3 changes.

2. Add the following integration tests to `studio-bridge-server.test.ts`:

   a. **v2 handshake test**: Connect a mock WebSocket client that sends a v2 `hello` with `protocolVersion: 2` and `capabilities: ['execute', 'queryState', 'captureScreenshot']`. Verify the server responds with a v2 `welcome` containing `protocolVersion: 2` and negotiated capabilities.

   b. **v2 register handshake test**: Connect a mock WebSocket client that sends a `register` message with all v2 fields (`protocolVersion`, `pluginVersion`, `instanceId`, `placeName`, `state`, `capabilities`). Verify the server responds with a v2 `welcome`.

   c. **v1 backward compatibility test**: Connect a mock WebSocket client that sends a v1 `hello` (no `protocolVersion`, no `capabilities`). Verify the server responds with a v1 `welcome` (no `protocolVersion` in the response). Verify `protocolVersion` getter returns 1.

   d. **Registry integration test**: Connect a mock plugin, verify it appears in `listSessionsAsync()`. Disconnect the plugin, verify it is removed from `listSessionsAsync()`.

   e. **Persistent plugin detection test**: Mock `isPersistentPluginInstalled()` to return `true`, start the server with `preferPersistentPlugin: true`, connect a mock plugin within the grace period, verify no temporary injection occurs. Then test the fallback: mock `isPersistentPluginInstalled()` to return `true`, do NOT connect a plugin, verify temporary injection is called after the grace period.

   f. **Heartbeat acceptance test**: Connect a v2 mock plugin, send a `heartbeat` message, verify no error response and the server continues operating normally.

   g. **performActionAsync test**: Connect a v2 mock plugin with `queryState` capability. Call `performActionAsync({ type: 'queryState', ... })`. Respond with a `stateResult` from the mock plugin. Verify the promise resolves with the correct data.

3. Verify that ALL existing tests still pass after modifications: `cd tools/studio-bridge && npx vitest run`.

**Acceptance Criteria**:
- All existing tests pass without modification (or with minimal fixes for intentional API changes).
- New v2 handshake tests cover both `hello` and `register` paths.
- v1 backward compatibility is verified.
- Registry integration (session tracking) is tested.
- Persistent plugin detection with grace period is tested.
- `cd tools/studio-bridge && npx vitest run` passes with zero failures.

**Do NOT**:
- Delete any existing tests (update them if the API changed, but do not remove coverage).
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 6.2: End-to-End Test Suite

**Prerequisites**: All of Phases 1-4 must be completed first.

**Context**: The system needs end-to-end tests that exercise the full lifecycle across all components: plugin connection, handshake, command execution, session management, split-server relay, and failover recovery.

**Objective**: Create a comprehensive E2E test suite with a shared mock plugin client helper.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/studio-bridge-server.ts` (server under test)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/bridge-connection.ts` (bridge connection API)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/server/web-socket-protocol.ts` (v2 protocol types)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/bridge/internal/bridge-host.ts` (host implementation)
- `/workspaces/NevermoreEngine/studio-bridge/plans/execution/validation/shared-test-utilities.md` (MockPluginClient spec)

**Files to Create**:
- `src/test/helpers/mock-plugin-client.ts` -- reusable mock plugin that speaks the v2 protocol
- `src/test/e2e/persistent-session.test.ts` -- persistent plugin lifecycle tests
- `src/test/e2e/split-server.test.ts` -- bridge host + remote client relay tests
- `src/test/e2e/hand-off.test.ts` -- full-stack failover scenarios

**Requirements**:

1. **`mock-plugin-client.ts`** -- Create a reusable mock plugin client:

```typescript
export interface MockPluginClientOptions {
  port: number;
  instanceId?: string;
  context?: 'edit' | 'client' | 'server';
  placeName?: string;
  capabilities?: Capability[];
  protocolVersion?: number;
}

export class MockPluginClient {
  async connectAsync(): Promise<void>;
  async sendRegisterAsync(): Promise<void>;
  async waitForWelcomeAsync(timeoutMs?: number): Promise<WelcomeMessage>;
  async disconnectAsync(): Promise<void>;
  onMessage(type: string, handler: (msg: any) => any): void;
  get isConnected(): boolean;
  get sessionId(): string;
}
```

2. **`persistent-session.test.ts`** -- Test the full persistent session lifecycle:
   - Plugin connects, sends `register`, receives `welcome` with capabilities.
   - Server sends `execute`, plugin sends `output` + `scriptComplete`.
   - Server sends `queryState`, plugin sends `stateResult`.
   - Server sends `captureScreenshot`, plugin sends `screenshotResult` with base64 data.
   - Server sends `queryDataModel`, plugin sends `dataModelResult`.
   - Server sends `queryLogs`, plugin sends `logsResult`.
   - Plugin sends `heartbeat`, server accepts silently.
   - Plugin disconnects, session is removed from list.
   - Plugin reconnects with new session ID but same instance ID.

3. **`split-server.test.ts`** -- Test bridge host + remote client:
   - Start a bridge host (`BridgeConnection.connectAsync({ keepAlive: true })`).
   - Connect a mock plugin to the host.
   - Connect a bridge client (`BridgeConnection.connectAsync({ remoteHost: ... })`).
   - From the client, list sessions and verify the plugin's session appears.
   - From the client, execute a command (e.g., `queryState`) and verify it relays through the host to the plugin and back.
   - Disconnect the client, verify the host and plugin remain connected.

4. **`hand-off.test.ts`** -- Test full-stack failover:
   - Start host, connect plugin and client.
   - Kill host, verify client promotes to host.
   - Verify plugin reconnects to the new host.
   - Verify commands work through the new host.

5. All tests must:
   - Use ephemeral ports (`port: 0`) to avoid conflicts.
   - Clean up all connections in `afterEach`.
   - Use `vi.useFakeTimers()` for timing-sensitive assertions.
   - Complete within 30 seconds per test file.

**Acceptance Criteria**:
- `MockPluginClient` speaks the v2 protocol and is reusable across all E2E test files.
- Persistent session lifecycle test covers: connect, register, execute, queryState, captureScreenshot, queryDataModel, queryLogs, heartbeat, disconnect, reconnect.
- Split-server test verifies command relay through the bridge host.
- Hand-off test verifies failover and plugin reconnection.
- All tests pass: `cd tools/studio-bridge && npx vitest run src/test/e2e/`.

**Do NOT**:
- Create ad-hoc WebSocket clients -- use `MockPluginClient` for all plugin simulation.
- Hard-code port numbers.
- Use default exports.
- Forget `.js` extensions on local imports.

---

## Task 6.3: Migration Guide

**Prerequisites**: All phases (0-5) must be completed first. The guide must reflect the final implemented behavior.

**Context**: Users of the existing studio-bridge need a migration guide covering the new features. The guide should be practical and task-oriented, not a reference manual.

**Objective**: Write a user-facing migration guide covering the key new capabilities.

**Read First**:
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/index.ts` (public API surface)
- `/workspaces/NevermoreEngine/tools/studio-bridge/src/commands/index.ts` (all available commands)
- `/workspaces/NevermoreEngine/tools/studio-bridge/package.json` (version, bin entry)
- `/workspaces/NevermoreEngine/studio-bridge/plans/tech-specs/00-overview.md` (feature overview)

**Files to Create**:
- Documentation content at a location determined by the docs structure (e.g., `docs/studio-bridge/migration-guide.md` or within the `tools/studio-bridge/` directory)

**Requirements**:

1. **Installing the persistent plugin**:
   - `studio-bridge install-plugin` command and what it does.
   - Where the plugin file is placed (platform-specific paths).
   - How to verify installation (`studio-bridge sessions` shows the plugin).
   - How to uninstall (`studio-bridge uninstall-plugin`).

2. **New CLI commands**:
   - `studio-bridge state` -- query Studio state.
   - `studio-bridge screenshot` -- capture viewport screenshot.
   - `studio-bridge logs` -- retrieve and stream output logs.
   - `studio-bridge query <path>` -- query the DataModel.
   - `studio-bridge sessions` -- list active sessions.
   - Brief description and most-used flags for each.

3. **Split-server mode for devcontainers**:
   - When to use it (Docker/devcontainer/Codespaces environments).
   - How to start the host: `studio-bridge serve` on the host OS.
   - How to connect from the container: automatic detection or `--remote host:port`.
   - Port forwarding requirements.

4. **MCP configuration for AI agents**:
   - How to register `studio-bridge mcp` as a Claude Code MCP tool provider.
   - Example `.mcp.json` configuration.
   - List of available MCP tools (`studio_sessions`, `studio_state`, `studio_screenshot`, `studio_logs`, `studio_query`, `studio_exec`).

5. **Breaking changes** (if any):
   - Document any changes to existing command behavior.
   - Document any changes to the programmatic API (`index.ts` exports).

**Acceptance Criteria**:
- Guide covers all four sections: persistent plugin, new commands, split-server, MCP.
- Each section has a concrete "getting started" example.
- All command names and flags match the actual implementation.
- Guide is accurate against the implemented code (review agent should verify).
- Guide is concise: aim for 2-4 pages total, not a reference manual.

**Do NOT**:
- Include implementation details that users do not need.
- Reference internal types or file paths.
- Create placeholder sections for unimplemented features.

---

## Cross-References

- Phase plan: [studio-bridge/plans/execution/phases/06-integration.md](../phases/06-integration.md)
- Validation: [studio-bridge/plans/execution/validation/06-integration.md](../validation/06-integration.md)
- Tech spec: `studio-bridge/plans/tech-specs/00-overview.md`
