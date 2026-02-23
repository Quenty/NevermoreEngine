/**
 * Unit tests for environment-detection -- validates role detection logic
 * including host election on free port, client detection when host exists,
 * and remoteHost override.
 */

import { describe, it, expect, afterEach } from 'vitest';
import { detectRoleAsync } from './environment-detection.js';
import { BridgeHost } from './bridge-host.js';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('detectRoleAsync', () => {
  let bridgeHost: BridgeHost | undefined;

  afterEach(async () => {
    if (bridgeHost) {
      await bridgeHost.stopAsync();
      bridgeHost = undefined;
    }
  });

  it('returns host role on a free ephemeral port', async () => {
    const result = await detectRoleAsync({ port: 0 });

    expect(result.role).toBe('host');
    expect(result.port).toBeGreaterThan(0);
  });

  it('returns client role when remoteHost is specified', async () => {
    const result = await detectRoleAsync({
      port: 38741,
      remoteHost: 'some-remote-host:38741',
    });

    expect(result.role).toBe('client');
    expect(result.port).toBe(38741);
  });

  it('returns client role when a bridge host is already running', async () => {
    // Start a real bridge host on an ephemeral port
    bridgeHost = new BridgeHost();
    const port = await bridgeHost.startAsync({ port: 0 });

    const result = await detectRoleAsync({ port });

    expect(result.role).toBe('client');
    expect(result.port).toBe(port);
  });

  it('preserves the port from options in the result', async () => {
    const result = await detectRoleAsync({
      port: 12345,
      remoteHost: 'localhost:12345',
    });

    expect(result.port).toBe(12345);
  });

  it('returns host role with the bound port when port is 0', async () => {
    const result = await detectRoleAsync({ port: 0 });

    // Ephemeral port should be assigned by the OS
    expect(result.role).toBe('host');
    expect(result.port).not.toBe(0);
    expect(result.port).toBeGreaterThan(0);
  });
});
