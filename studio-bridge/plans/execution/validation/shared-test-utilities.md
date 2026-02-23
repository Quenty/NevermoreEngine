# Shared Test Utilities

Standardized test infrastructure used across all validation phases. All test files that interact with a plugin connection MUST use the `MockPluginClient` defined here instead of ad-hoc WebSocket mocks.

**Applies to**: Phases 1, 2, 3, 4, 5, 6

---

## MockPluginClient

A reusable test helper that simulates a v2 plugin connecting to the bridge server over WebSocket. Encapsulates the connection lifecycle (register/welcome handshake), heartbeat auto-response, and action handling so that individual test files do not need to manage raw WebSocket frames.

### Interface

```typescript
import { EventEmitter } from "node:events";

/** Session context for multi-context support */
type SessionContext = "edit" | "client" | "server";

interface MockPluginClientOptions {
  /** Port to connect to. Default: 38741 */
  port?: number;
  /** Instance ID to register with. Default: auto-generated UUID */
  instanceId?: string;
  /** Session context. Default: 'edit' */
  context?: SessionContext;
  /** Protocol version to advertise. Default: 2 */
  protocolVersion?: number;
  /** Whether to auto-respond to heartbeats. Default: true */
  autoHeartbeat?: boolean;
  /** Delay before responding to actions (ms). Default: 0 (immediate) */
  responseDelay?: number;
  /** Capabilities to advertise. Default: all v2 capabilities */
  capabilities?: string[];
  /** Plugin version string. Default: '1.0.0' */
  pluginVersion?: string;
  /** Place name to register with. Default: 'TestPlace' */
  placeName?: string;
  /** Initial studio state. Default: 'Edit' */
  state?: string;
  /** Place ID. Default: undefined */
  placeId?: number;
  /** Game ID. Default: undefined */
  gameId?: number;
}

class MockPluginClient {
  constructor(options?: MockPluginClientOptions);

  /** Connect and complete register/welcome handshake */
  connectAsync(): Promise<void>;

  /** Disconnect cleanly (sends proper close frame) */
  disconnectAsync(): Promise<void>;

  /** Get the assigned session ID (available after connect) */
  get sessionId(): string;

  /** Get the instance ID this mock was created with */
  get instanceId(): string;

  /** Get the context this mock was created with */
  get context(): SessionContext;

  /** Register a handler for a specific action type (e.g., 'queryState', 'execute') */
  onAction(type: string, handler: (request: ActionRequest) => any): void;

  /** Get all messages received from the server (for assertions) */
  get receivedMessages(): BaseMessage[];

  /** Send a raw string over the WebSocket (for testing malformed inputs) */
  sendRaw(data: string): void;

  /** Simulate a crash (close WebSocket abruptly without clean shutdown) */
  crash(): void;

  /** Whether the WebSocket is currently connected */
  get isConnected(): boolean;
}

interface ActionRequest {
  type: string;
  requestId: string;
  sessionId: string;
  payload: Record<string, unknown>;
}

interface BaseMessage {
  type: string;
  sessionId?: string;
  requestId?: string;
  payload?: Record<string, unknown>;
}
```

### Design Decisions

The following questions were raised in the final review and are answered here:

#### Response delay

Configurable via the `responseDelay` option. Default is `0` (immediate). When set to a nonzero value, the mock waits the specified number of milliseconds before sending any action response. This allows tests to exercise timeout logic, concurrent request handling, and partial-response scenarios without modifying the mock between tests.

When `vi.useFakeTimers()` is active (which it MUST be for all timing-sensitive tests -- see the Testing Conventions section in `agent-prompts/00-prerequisites.md`), the response delay is scheduled via `setTimeout` and advanced deterministically with `vi.advanceTimersByTime()`. The mock does NOT use `Date.now()` or wall-clock measurements internally.

#### Buffering / batching

The mock sends responses immediately (no batching). Each action response is sent as a single WebSocket frame as soon as the response delay (if any) has elapsed. This matches the behavior of the real plugin, which also sends responses individually. Tests that need to verify batching behavior on the server side can use multiple `MockPluginClient` instances or the `sendRaw` method.

#### Protocol version

Configurable via the `protocolVersion` option. Default is `2`. Set to `1` (or omit `protocolVersion` from the register message) to simulate a v1 plugin. When `protocolVersion` is `1`, the mock sends a v1 `hello` message instead of a v2 `register` message during `connectAsync()`, and does not send heartbeats or handle action requests (since v1 plugins do not support these).

#### WebSocket interface

The underlying WebSocket connection is internal to the mock and not directly exposed. Tests interact with the mock through the high-level methods (`connectAsync`, `disconnectAsync`, `onAction`, `sendRaw`, `crash`). This ensures tests are not coupled to WebSocket implementation details and can focus on protocol-level behavior.

The `sendRaw` method provides an escape hatch for tests that need to send malformed data, partial frames, or non-JSON content. The `crash` method closes the underlying socket without a clean WebSocket close handshake, simulating an abrupt plugin crash or network failure.

### Usage Examples

#### Basic connection test

```typescript
import { MockPluginClient } from "../test-utils/mock-plugin-client.js";

it("connects and registers", async () => {
  const mock = new MockPluginClient({ port: server.port });
  await mock.connectAsync();
  expect(mock.sessionId).toBeDefined();
  await mock.disconnectAsync();
});
```

#### Action handler test

```typescript
it("handles queryState action", async () => {
  const mock = new MockPluginClient({ port: server.port });
  await mock.connectAsync();

  mock.onAction("queryState", (request) => ({
    state: "Edit",
    placeId: 123,
    placeName: "TestPlace",
    gameId: 456,
  }));

  const result = await server.performActionAsync({
    type: "queryState",
    sessionId: mock.sessionId,
  });

  expect(result.state).toBe("Edit");
  await mock.disconnectAsync();
});
```

#### Timeout test with fake timers

```typescript
it("rejects on action timeout", async () => {
  vi.useFakeTimers();

  const mock = new MockPluginClient({ port: server.port });
  await mock.connectAsync();

  // Do NOT register an action handler -- mock will not respond
  const promise = server.performActionAsync({
    type: "queryState",
    sessionId: mock.sessionId,
    timeoutMs: 5000,
  });

  vi.advanceTimersByTime(5000);
  await expect(promise).rejects.toThrow("timed out");

  await mock.disconnectAsync();
  vi.useRealTimers();
});
```

#### Multi-context Play mode test

```typescript
it("handles Play mode with 3 contexts", async () => {
  const instanceId = "inst-1";
  const edit = new MockPluginClient({ port: server.port, instanceId, context: "edit" });
  const client = new MockPluginClient({ port: server.port, instanceId, context: "client" });
  const serverCtx = new MockPluginClient({ port: server.port, instanceId, context: "server" });

  await edit.connectAsync();
  await client.connectAsync();
  await serverCtx.connectAsync();

  const sessions = await connection.listSessionsAsync();
  expect(sessions).toHaveLength(3);

  await client.disconnectAsync();
  await serverCtx.disconnectAsync();
  await edit.disconnectAsync();
});
```

#### Simulating a crash

```typescript
it("detects plugin crash", async () => {
  const mock = new MockPluginClient({ port: server.port });
  await mock.connectAsync();

  mock.crash(); // Abrupt close, no clean shutdown

  // Server should detect the disconnect and remove the session
  await vi.waitFor(() => {
    expect(connection.listSessions()).toHaveLength(0);
  });
});
```

### File Location

The implementation should live at:
```
tools/studio-bridge/src/test-utils/mock-plugin-client.ts
```

This is a test-only utility and MUST NOT be exported from the package's public API (`index.ts`). It should be importable from any test file within the `studio-bridge` package.
