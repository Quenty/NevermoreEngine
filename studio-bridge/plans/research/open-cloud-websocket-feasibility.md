# Open Cloud WebSocket Feasibility Research

**Date:** 2026-02-20
**Question:** Can the cloud test runner connect to the bridge host via WebSocket, unifying the plugin test path with the cloud batch test runner?

## Executive Summary

**Recommendation: Not feasible via WebSocket. Partially feasible via HTTP long-polling, but not worth the complexity.**

WebSocket connections from Roblox cloud game servers (RCC) are explicitly blocked. HTTP outbound requests from Open Cloud Luau execution tasks are available (the blocklist was removed in November 2024), but the cloud execution environment cannot reach a developer's local machine. The fundamental networking topology makes real-time bidirectional communication between a cloud game server and a developer's localhost impractical without significant infrastructure (public tunnels, relay servers). The current two-path architecture (local Studio via WebSocket, cloud via Open Cloud Luau Execution API) is well-designed for each environment's constraints and should be maintained.

---

## 1. WebSocket Capabilities in Roblox

### Studio: Full WebSocket Support

Roblox Studio supports WebSocket connections via `HttpService:CreateWebStreamClient()` with `Enum.WebStreamClientType.WebSocket`. This is what the studio-bridge plugin currently uses to connect to `ws://localhost:<port>/<sessionId>`.

Key facts:
- Maximum 4 concurrent WebStreamClient connections (shared with SSE)
- Studio-only: documentation explicitly states "This feature is restricted to Studio only. Any CreateWebStreamClient() requests made in a live experience will be blocked."
- Announced as available in Studio in a [2025 DevForum post](https://devforum.roblox.com/t/websockets-support-in-studio-is-now-available/4021932)

### Game Servers (RCC): WebSocket Blocked

`CreateWebStreamClient()` is **not available** in game servers. Attempting to use it returns the error `"WebStreamClient is not enabled in RCC"`. This is confirmed by:
- [DevForum discussion on Open Cloud Luau Execution](https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185/85)
- [Official HttpService documentation](https://create.roblox.com/docs/reference/engine/classes/HttpService) stating CreateWebStreamClient is Studio-only
- [SSE announcement](https://devforum.roblox.com/t/http-streaming-now-supports-server-sent-events-in-studio/3905367) confirming Studio-only restriction

**Verdict: WebSocket from cloud game servers is not possible.**

### Open Cloud Luau Execution Environment

The Open Cloud Engine API for Executing Luau spins up a headless RCC instance. The same RCC restrictions apply. WebSocket is unavailable.

## 2. HTTP Capabilities in Cloud Game Servers

### HttpService in Open Cloud Luau Execution

HttpService was initially blocked in the Open Cloud Luau Execution environment but the [engine API restrictions were lifted as of November 2024](https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185?page=3). Scripts executed via the Open Cloud Luau Execution API can now use:
- `HttpService:GetAsync()`
- `HttpService:PostAsync()`
- `HttpService:RequestAsync()`

### Rate Limits

- **External HTTP requests:** 500 requests per minute per game server
- **Open Cloud requests:** 2500 requests per minute
- **Port restrictions:** Ports below 1024 are blocked except 80 and 443. Ports 1024-65535 are allowed (except 1194).

### Localhost / Private IP Restrictions

Roblox game servers **cannot access localhost (127.0.0.1) or private IP addresses**. This is a security restriction that applies to all RCC environments. The game server runs in Roblox's cloud infrastructure, not on the developer's machine.

This is the critical blocker: even if HttpService is available, the cloud game server cannot reach a developer's local bridge host.

### Execution Constraints

From the [Luau Execution documentation](https://create.roblox.com/docs/cloud/reference/features/luau-execution):
- Scripts can execute for up to **5 minutes** maximum
- Limited to **10 concurrent tasks** per place
- Maximum **450 KB** of output logs
- Script size up to **4 MB**
- Return value serialization up to **4 MB** (JSON) or **256 MiB** (binary)

## 3. Alternative Transport: MessagingService

[MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService) enables cross-server communication within a universe. There is also an [Open Cloud Messaging API](https://devforum.roblox.com/t/announcing-messaging-service-api-for-open-cloud/1863229) that allows external services to publish messages to game servers.

### How It Could Work

1. Bridge host publishes a message to the game server via Open Cloud Messaging API
2. Game server's Luau script subscribes to a topic and receives the message
3. Game server responds by making an HTTP POST to a publicly-reachable endpoint

### Limitations

- **Message size:** 1 KB maximum per message (extremely limiting for sending scripts)
- **Rate limits:** 600 + 240*players per minute for sending; 40 + 80*servers per minute for receiving per topic
- **Best-effort delivery:** Not guaranteed
- **Unidirectional from Open Cloud:** External services can only publish, not subscribe. The game server would need another channel to respond.
- **Requires a running game server:** MessagingService works within a live experience, not within Open Cloud Luau Execution tasks.

**Verdict: MessagingService is not suitable for bidirectional command-and-control communication.**

## 4. Current Architecture Analysis

### Cloud Testing Path (nevermore-cli)

The current cloud testing path is well-architected for the constraints:

1. **`nevermore test --cloud`** or **`nevermore batch test --cloud`** invokes the CLI
2. **`CloudJobContext`** (`tools/nevermore-cli/src/utils/job-context/cloud-job-context.ts`):
   - Uploads a built `.rbxl` place file via Open Cloud Place API
   - Creates a Luau execution task via `OpenCloudClient.createExecutionTaskAsync()`
   - Polls for task completion via `OpenCloudClient.pollTaskCompletionAsync()` (3-second intervals)
   - Retrieves logs via `OpenCloudClient.getRawTaskLogsAsync()`
3. **`batch-test-runner.luau`** (`tools/nevermore-cli/templates/batch-test-runner.luau`):
   - Runs inside the headless RCC instance
   - Discovers test scripts via CollectionService tags
   - Isolates packages by reparenting them in ServerScriptService
   - Executes tests sequentially with `loadstring()`
   - Outputs structured markers (`===BATCH_TEST_BEGIN===`, `===BATCH_TEST_END===`) for log parsing
   - Reports results as JSON via `print(HttpService:JSONEncode(results))`
4. **Results flow back** via the Open Cloud logs API, parsed by `parseBatchTestLogs()`

### Local Testing Path (studio-bridge)

1. **`StudioBridgeServer`** (`tools/studio-bridge/src/server/studio-bridge-server.ts`):
   - Starts a WebSocket server on a random port on localhost
   - Injects a plugin `.rbxm` into Studio's plugins folder (port + session ID baked in)
   - Launches Studio with the built place
   - Plugin connects via WebSocket, does handshake (hello/welcome)
   - Server sends `execute` messages with script content
   - Plugin executes via `loadstring()`, streams output via LogService, sends `scriptComplete`
2. **`LocalJobContext`** (`tools/nevermore-cli/src/utils/job-context/local-job-context.ts`):
   - Wraps `StudioBridgeServer` as a `JobContext` implementation
   - Same interface as `CloudJobContext` (build, deploy, run script, get logs, release)

### Key Difference

| Aspect | Local (Studio) | Cloud (Open Cloud) |
|--------|---------------|-------------------|
| Transport | WebSocket (bidirectional, real-time) | Open Cloud REST API (poll-based) |
| Script delivery | WebSocket `execute` message | Luau Execution API `createExecutionTaskAsync` |
| Output streaming | Real-time via WebSocket `output` messages | Post-hoc via logs API |
| Execution host | Developer's machine (Studio) | Roblox cloud infrastructure (RCC) |
| Network reachability | localhost (same machine) | Internet-only (no localhost, no private IPs) |

### The JobContext Abstraction Already Unifies

The `JobContext` interface (`tools/nevermore-cli/src/utils/job-context/job-context.ts`) already provides the unification layer. Both `CloudJobContext` and `LocalJobContext` implement the same interface:
- `buildPlaceAsync()`
- `deployBuiltPlaceAsync()`
- `runScriptAsync()`
- `getLogsAsync()`
- `releaseAsync()`
- `disposeAsync()`

The `BatchScriptJobContext` wraps either inner context transparently. From the batch runner's perspective, cloud and local are already interchangeable.

## 5. What Unification Would Require

### Option A: WebSocket from Cloud (Blocked)

Not possible. `CreateWebStreamClient()` is Studio-only.

### Option B: HTTP Long-Polling from Cloud

The game server would need to poll a publicly-reachable bridge host for commands, and POST results back.

**Requirements:**
1. Bridge host exposed to the internet (via ngrok, Cloudflare Tunnel, or a public server)
2. HTTP polling endpoint on the bridge host (GET for next command, POST for results)
3. Modified plugin that detects "cloud mode" and uses HttpService polling instead of WebSocket
4. Session management to match the polling game server to the correct bridge instance

**Problems:**
- **Latency:** 0.5-3 second polling intervals, versus instant WebSocket delivery
- **Security:** Exposing the bridge host to the internet creates attack surface. The bridge can execute arbitrary Luau. An authenticated tunnel would be required.
- **Complexity:** HTTP polling transport adds significant complexity to the plugin for marginal benefit
- **5-minute timeout:** Open Cloud Luau Execution tasks time out at 5 minutes, limiting test duration
- **Reliability:** Network path is cloud server -> internet -> tunnel -> developer machine. Many points of failure.
- **No clear benefit over current approach:** The current log-based protocol works reliably for batch testing

### Option C: External Relay Server

A relay server (e.g., a lightweight WebSocket-to-HTTP bridge deployed on a cloud provider) could mediate:
1. Bridge host connects to relay via WebSocket (outbound, so no port opening needed)
2. Cloud game server polls relay via HTTP
3. Relay forwards messages bidirectionally

**Problems:**
- Requires deploying and maintaining infrastructure
- Adds latency and a point of failure
- Cost and operational burden for a dev tool
- Same 5-minute timeout and other Open Cloud constraints still apply

## 6. Feasibility Assessment

### Blockers

| Blocker | Severity | Notes |
|---------|----------|-------|
| No WebSocket in RCC | **Hard blocker** | Platform limitation, no workaround |
| No localhost access from RCC | **Hard blocker** | Cloud game servers cannot reach developer machines |
| 5-minute execution timeout | **Significant** | Limits interactive debugging sessions |
| Bridge host must be internet-reachable | **Significant** | Requires tunnel/relay infrastructure |
| 1 KB MessagingService limit | **Hard blocker** for MessagingService path | Cannot send scripts (often >1 KB) |

### What Would Change

Even with a working transport:
- Plugin would need a second boot mode (HTTP polling) alongside WebSocket
- Bridge host would need HTTP endpoints alongside WebSocket server
- Session discovery would need to work across the internet (not just localhost)
- Authentication would be required (API keys, tokens)
- The entire debugging experience would have higher latency

### What Already Works

The current architecture already achieves the core goal:
- **Same test runner logic:** `runSingleTestAsync()` works identically with both contexts
- **Same reporting:** `CompositeReporter` and all reporter types work with both paths
- **Same batch aggregation:** `BatchScriptJobContext` wraps either inner context
- **Same result format:** Both paths produce `SingleTestResult` with success + logs

The only thing that differs is the transport layer, and that difference is inherent to the environment constraints.

## 7. Recommendation

**Do not pursue WebSocket/HTTP unification between cloud and local paths.**

The current two-path architecture is the correct design for the platform constraints:
- **Local Studio testing** uses WebSocket for real-time bidirectional communication (the only environment where it works)
- **Cloud testing** uses the Open Cloud Luau Execution API for headless batch execution (the only way to run code in cloud game servers)
- **The `JobContext` interface** already provides the abstraction that makes both paths interchangeable from the caller's perspective

### Where to Invest Instead

If the goal is to improve the cloud testing experience, better investments would be:

1. **Improve cloud test output fidelity:** The current log-based protocol loses message types (print vs warn vs error). The Open Cloud team has a [feature request](https://devforum.roblox.com/t/include-output-type-in-open-cloud-luau-execution-logs/3420642) for this.

2. **Studio-bridge plugin improvements:** Make the local plugin more robust (reconnection, multiple script execution, persistent mode) as planned in the current tech specs.

3. **Cloud test result streaming:** Instead of waiting for the entire execution to complete, poll the logs endpoint periodically during execution to provide incremental feedback. This would make cloud tests feel more interactive without requiring a WebSocket connection from the game server.

4. **Watch mode for cloud:** When `--watch` is combined with `--cloud`, rebuild and re-upload on file changes. The transport is still Open Cloud API, but the iteration loop is faster.

## Appendix: Sources

- [Roblox HttpService Documentation](https://create.roblox.com/docs/reference/engine/classes/HttpService)
- [WebSocket Support in Studio Announcement](https://devforum.roblox.com/t/websockets-support-in-studio-is-now-available/4021932)
- [HTTP Streaming / SSE Announcement](https://devforum.roblox.com/t/http-streaming-now-supports-server-sent-events-in-studio/3905367)
- [Open Cloud Engine API for Executing Luau](https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185)
- [Luau Execution Documentation](https://create.roblox.com/docs/cloud/reference/features/luau-execution)
- [Port Restrictions for HttpService](https://devforum.roblox.com/t/port-restrictions-for-httpservice/1500073)
- [Open Cloud Messaging API](https://devforum.roblox.com/t/announcing-messaging-service-api-for-open-cloud/1863229)
- [MessagingService Documentation](https://create.roblox.com/docs/reference/engine/classes/MessagingService)
- [Cross-Server Messaging Guide](https://create.roblox.com/docs/cloud-services/cross-server-messaging)
- [Open Cloud via HttpService Without Proxies](https://devforum.roblox.com/t/use-open-cloud-via-httpservice-without-proxies/3656373)
