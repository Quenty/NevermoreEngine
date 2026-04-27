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
});
