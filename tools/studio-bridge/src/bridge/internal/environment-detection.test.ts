/**
 * Unit tests for environment-detection -- validates role detection logic
 * including host election on free port, client detection when host exists,
 * remoteHost override, and devcontainer detection.
 */

import { existsSync } from 'node:fs';
import { describe, it, expect, afterEach, beforeEach } from 'vitest';
import { detectRoleAsync, isDevcontainer, getDefaultRemoteHost } from './environment-detection.js';
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

// ---------------------------------------------------------------------------
// Devcontainer detection tests
// ---------------------------------------------------------------------------

const DEVCONTAINER_ENV_KEYS = ['REMOTE_CONTAINERS', 'CODESPACES', 'CONTAINER'] as const;
const dockerenvExists = existsSync('/.dockerenv');

describe('isDevcontainer', () => {
  const savedEnv: Record<string, string | undefined> = {};

  beforeEach(() => {
    // Save current values so we can restore after each test
    for (const key of DEVCONTAINER_ENV_KEYS) {
      savedEnv[key] = process.env[key];
    }
  });

  afterEach(() => {
    // Restore original env values
    for (const key of DEVCONTAINER_ENV_KEYS) {
      if (savedEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = savedEnv[key];
      }
    }
  });

  function clearDevcontainerEnv(): void {
    for (const key of DEVCONTAINER_ENV_KEYS) {
      delete process.env[key];
    }
  }

  it('returns true when REMOTE_CONTAINERS is set', () => {
    clearDevcontainerEnv();
    process.env.REMOTE_CONTAINERS = 'true';
    expect(isDevcontainer()).toBe(true);
  });

  it('returns true when CODESPACES is set', () => {
    clearDevcontainerEnv();
    process.env.CODESPACES = 'true';
    expect(isDevcontainer()).toBe(true);
  });

  it('returns true when CONTAINER is set', () => {
    clearDevcontainerEnv();
    process.env.CONTAINER = 'true';
    expect(isDevcontainer()).toBe(true);
  });

  it('returns false when no env vars set and no /.dockerenv', () => {
    clearDevcontainerEnv();
    // If /.dockerenv exists on this machine, the function should still return true
    expect(isDevcontainer()).toBe(dockerenvExists);
  });

  it('treats empty string as falsy', () => {
    clearDevcontainerEnv();
    process.env.REMOTE_CONTAINERS = '';
    // Empty string is falsy -- result depends only on /.dockerenv
    expect(isDevcontainer()).toBe(dockerenvExists);
  });
});

describe('getDefaultRemoteHost', () => {
  const savedEnv: Record<string, string | undefined> = {};

  beforeEach(() => {
    for (const key of DEVCONTAINER_ENV_KEYS) {
      savedEnv[key] = process.env[key];
    }
  });

  afterEach(() => {
    for (const key of DEVCONTAINER_ENV_KEYS) {
      if (savedEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = savedEnv[key];
      }
    }
  });

  function clearDevcontainerEnv(): void {
    for (const key of DEVCONTAINER_ENV_KEYS) {
      delete process.env[key];
    }
  }

  it('returns localhost:38741 in devcontainer', () => {
    clearDevcontainerEnv();
    process.env.REMOTE_CONTAINERS = 'true';
    expect(getDefaultRemoteHost()).toBe('localhost:38741');
  });

  it('returns null outside devcontainer', () => {
    clearDevcontainerEnv();
    // Only null if /.dockerenv doesn't exist
    if (!dockerenvExists) {
      expect(getDefaultRemoteHost()).toBeNull();
    } else {
      // If /.dockerenv exists, we're in a container, so it returns the host
      expect(getDefaultRemoteHost()).toBe('localhost:38741');
    }
  });
});
