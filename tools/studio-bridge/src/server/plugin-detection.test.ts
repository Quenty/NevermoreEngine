/**
 * Tests for persistent plugin detection and fallback logic in
 * StudioBridgeServer.startAsync(). Validates the grace period behavior,
 * persistent plugin preference, and fallback to temp injection.
 */

import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest';
import { WebSocket } from 'ws';
import { StudioBridgeServer } from './studio-bridge-server.js';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

vi.mock('@quenty/nevermore-template-helpers', () => ({
  BuildContext: {
    createAsync: vi.fn(async () => ({
      resolvePath: vi.fn((rel: string) => `/fake/tmp/${rel}`),
      executeLuneTransformScriptAsync: vi.fn(async () => {}),
      rojoBuildAsync: vi.fn(async () => undefined),
      cleanupAsync: vi.fn(async () => {}),
    })),
  },
  resolvePackagePath: vi.fn((..._args: any[]) => '/fake/transform-script.luau'),
  resolveTemplatePath: vi.fn((..._args: any[]) => '/fake/default.project.json'),
}));

const mockInjectPluginAsync = vi.fn(async () => ({
  pluginPath: '/fake/plugin.rbxmx',
  cleanupAsync: vi.fn(async () => {}),
}));

vi.mock('../plugin/plugin-injector.js', () => ({
  injectPluginAsync: (...args: any[]) => mockInjectPluginAsync(...args),
}));

const mockIsPersistentPluginInstalled = vi.fn(() => false);

vi.mock('../plugin/plugin-discovery.js', () => ({
  isPersistentPluginInstalled: () => mockIsPersistentPluginInstalled(),
}));

vi.mock('../process/studio-process-manager.js', () => ({
  launchStudioAsync: vi.fn(async () => ({
    process: { pid: 12345 },
    killAsync: vi.fn(async () => {}),
  })),
  findPluginsFolder: vi.fn(() => '/fake/plugins'),
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Connect a WebSocket client and perform the hello/welcome handshake.
 */
async function connectAndHandshake(
  port: number,
  sessionId: string,
): Promise<WebSocket> {
  const ws = new WebSocket(`ws://localhost:${port}/${sessionId}`);

  await new Promise<void>((resolve, reject) => {
    ws.on('open', resolve);
    ws.on('error', reject);
  });

  ws.send(JSON.stringify({ type: 'hello', sessionId, payload: { sessionId } }));

  await new Promise<void>((resolve) => {
    ws.on('message', (raw) => {
      const data = JSON.parse(
        typeof raw === 'string' ? raw : raw.toString('utf-8'),
      );
      if (data.type === 'welcome') {
        resolve();
      }
    });
  });

  return ws;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('persistent plugin detection', () => {
  let server: StudioBridgeServer | undefined;
  let client: WebSocket | undefined;

  beforeEach(() => {
    vi.clearAllMocks();
    mockIsPersistentPluginInstalled.mockReturnValue(false);
  });

  afterEach(async () => {
    if (client && client.readyState === WebSocket.OPEN) {
      client.close();
    }
    if (server) {
      await server.stopAsync();
    }
    client = undefined;
    server = undefined;
  });

  it('uses temp injection when persistent plugin is not installed', async () => {
    mockIsPersistentPluginInstalled.mockReturnValue(false);

    const sessionId = 'no-persistent';
    server = new StudioBridgeServer({
      placePath: '/fake/place.rbxl',
      sessionId,
      timeoutMs: 5_000,
    });

    const startPromise = server.startAsync();
    await new Promise((r) => setTimeout(r, 50));
    const port: number = (server as any)._port;

    // Temp injection should have been called immediately
    expect(mockInjectPluginAsync).toHaveBeenCalledTimes(1);

    // Complete handshake so startAsync resolves
    client = await connectAndHandshake(port, sessionId);
    await startPromise;
  });

  it('uses temp injection when preferPersistentPlugin is false', async () => {
    mockIsPersistentPluginInstalled.mockReturnValue(true);

    const sessionId = 'prefer-false';
    server = new StudioBridgeServer({
      placePath: '/fake/place.rbxl',
      sessionId,
      timeoutMs: 5_000,
      preferPersistentPlugin: false,
    });

    const startPromise = server.startAsync();
    await new Promise((r) => setTimeout(r, 50));
    const port: number = (server as any)._port;

    // Temp injection should have been called immediately
    expect(mockInjectPluginAsync).toHaveBeenCalledTimes(1);

    // Complete handshake so startAsync resolves
    client = await connectAndHandshake(port, sessionId);
    await startPromise;
  });

  it('falls back to temp injection after grace period when persistent plugin does not connect', async () => {
    mockIsPersistentPluginInstalled.mockReturnValue(true);

    const sessionId = 'grace-expire';
    server = new StudioBridgeServer({
      placePath: '/fake/place.rbxl',
      sessionId,
      timeoutMs: 10_000,
    });

    const startPromise = server.startAsync();

    // Wait for the grace period (3 seconds) to expire + some buffer
    // The server should fall back to temp injection after 3 seconds
    await new Promise((r) => setTimeout(r, 3_200));

    // After grace period, temp injection should have been called
    expect(mockInjectPluginAsync).toHaveBeenCalledTimes(1);

    // Complete handshake so startAsync resolves
    const port: number = (server as any)._port;
    client = await connectAndHandshake(port, sessionId);
    await startPromise;
  }, 15_000);

  it('skips temp injection when persistent plugin connects within grace period', async () => {
    mockIsPersistentPluginInstalled.mockReturnValue(true);

    const sessionId = 'plugin-connects';
    server = new StudioBridgeServer({
      placePath: '/fake/place.rbxl',
      sessionId,
      timeoutMs: 10_000,
    });

    const startPromise = server.startAsync();

    // Wait for the server to be up
    await new Promise((r) => setTimeout(r, 100));
    const port: number = (server as any)._port;

    // Connect a plugin within the grace period (simulating persistent plugin)
    client = await connectAndHandshake(port, sessionId);

    // Wait for startAsync to resolve
    await startPromise;

    // Temp injection should NOT have been called
    expect(mockInjectPluginAsync).not.toHaveBeenCalled();
  });
});
