import { describe, it, expect } from 'vitest';
import * as barrel from './index.js';

describe('index barrel exports', () => {
  it('exports existing StudioBridge class', () => {
    expect(barrel.StudioBridge).toBeDefined();
  });

  it('exports BridgeConnection class', () => {
    expect(barrel.BridgeConnection).toBeDefined();
  });

  it('exports BridgeSession class', () => {
    expect(barrel.BridgeSession).toBeDefined();
  });

  it('exports error classes', () => {
    expect(barrel.SessionNotFoundError).toBeDefined();
    expect(barrel.ActionTimeoutError).toBeDefined();
    expect(barrel.SessionDisconnectedError).toBeDefined();
    expect(barrel.CapabilityNotSupportedError).toBeDefined();
    expect(barrel.ContextNotFoundError).toBeDefined();
    expect(barrel.HostUnreachableError).toBeDefined();
  });

  it('exports protocol encoding/decoding functions', () => {
    expect(barrel.encodeMessage).toBeDefined();
    expect(barrel.decodePluginMessage).toBeDefined();
    expect(barrel.decodeServerMessage).toBeDefined();
  });

  it('exports studio process utilities', () => {
    expect(barrel.findStudioPathAsync).toBeDefined();
    expect(barrel.findPluginsFolder).toBeDefined();
    expect(barrel.launchStudioAsync).toBeDefined();
    expect(barrel.injectPluginAsync).toBeDefined();
  });

  it('exports plugin discovery', () => {
    expect(barrel.isPersistentPluginInstalled).toBeDefined();
  });

  it('exports command handler functions', () => {
    expect(barrel.listSessionsHandlerAsync).toBeDefined();
    expect(barrel.serveHandlerAsync).toBeDefined();
    expect(barrel.installPluginHandlerAsync).toBeDefined();
    expect(barrel.uninstallPluginHandlerAsync).toBeDefined();
    expect(barrel.queryStateHandlerAsync).toBeDefined();
    expect(barrel.queryLogsHandlerAsync).toBeDefined();
    expect(barrel.captureScreenshotHandlerAsync).toBeDefined();
    expect(barrel.queryDataModelHandlerAsync).toBeDefined();
    expect(barrel.execHandlerAsync).toBeDefined();
    expect(barrel.runHandlerAsync).toBeDefined();
    expect(barrel.launchHandlerAsync).toBeDefined();
    expect(barrel.connectHandlerAsync).toBeDefined();
    expect(barrel.disconnectHandler).toBeDefined();
    expect(barrel.mcpHandlerAsync).toBeDefined();
  });

  it('exports MCP server functions', () => {
    expect(barrel.startMcpServerAsync).toBeDefined();
    expect(barrel.buildToolDefinitions).toBeDefined();
    expect(barrel.createMcpTool).toBeDefined();
  });
});
