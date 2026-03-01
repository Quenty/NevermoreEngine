/**
 * Tests for action-loader: scanning .luau files and computing content hashes.
 */

import { createHash } from 'crypto';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { loadActionSourcesAsync } from './action-loader.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let tmpDir: string;

beforeEach(async () => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'action-loader-'));
});

afterEach(async () => {
  await fs.rm(tmpDir, { recursive: true, force: true });
});

function sha256(content: string): string {
  return createHash('sha256').update(content).digest('hex');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('loadActionSourcesAsync', () => {
  it('loads .luau files from a flat directory', async () => {
    const source = 'local M = {} return M';
    await fs.writeFile(path.join(tmpDir, 'hello.luau'), source);

    const results = await loadActionSourcesAsync(tmpDir);

    expect(results).toHaveLength(1);
    expect(results[0].name).toBe('hello');
    expect(results[0].source).toBe(source);
    expect(results[0].relativePath).toBe('hello.luau');
  });

  it('computes SHA-256 hash of source content', async () => {
    const source = 'return function() end';
    await fs.writeFile(path.join(tmpDir, 'test.luau'), source);

    const results = await loadActionSourcesAsync(tmpDir);

    expect(results).toHaveLength(1);
    expect(results[0].hash).toBe(sha256(source));
  });

  it('different content produces different hashes', async () => {
    await fs.writeFile(path.join(tmpDir, 'a.luau'), 'version 1');
    await fs.writeFile(path.join(tmpDir, 'b.luau'), 'version 2');

    const results = await loadActionSourcesAsync(tmpDir);

    expect(results).toHaveLength(2);
    const hashA = results.find((r) => r.name === 'a')!.hash;
    const hashB = results.find((r) => r.name === 'b')!.hash;
    expect(hashA).not.toBe(hashB);
  });

  it('identical content produces identical hashes', async () => {
    const source = 'local x = 42';
    const subDir = path.join(tmpDir, 'sub');
    await fs.mkdir(subDir);
    await fs.writeFile(path.join(tmpDir, 'a.luau'), source);
    await fs.writeFile(path.join(subDir, 'b.luau'), source);

    const results = await loadActionSourcesAsync(tmpDir);

    expect(results).toHaveLength(2);
    const hashA = results.find((r) => r.name === 'a')!.hash;
    const hashB = results.find((r) => r.name === 'b')!.hash;
    expect(hashA).toBe(hashB);
  });

  it('recursively scans subdirectories', async () => {
    const subDir = path.join(tmpDir, 'nested', 'deep');
    await fs.mkdir(subDir, { recursive: true });
    await fs.writeFile(path.join(subDir, 'deep.luau'), 'return nil');

    const results = await loadActionSourcesAsync(tmpDir);

    expect(results).toHaveLength(1);
    expect(results[0].name).toBe('deep');
    expect(results[0].relativePath).toBe(path.join('nested', 'deep', 'deep.luau'));
  });

  it('ignores non-.luau files', async () => {
    await fs.writeFile(path.join(tmpDir, 'script.lua'), 'not included');
    await fs.writeFile(path.join(tmpDir, 'module.ts'), 'not included');
    await fs.writeFile(path.join(tmpDir, 'action.luau'), 'included');

    const results = await loadActionSourcesAsync(tmpDir);

    expect(results).toHaveLength(1);
    expect(results[0].name).toBe('action');
  });

  it('returns empty array for empty directory', async () => {
    const results = await loadActionSourcesAsync(tmpDir);
    expect(results).toHaveLength(0);
  });

  it('returns empty array for non-existent directory', async () => {
    const results = await loadActionSourcesAsync(path.join(tmpDir, 'nope'));
    expect(results).toHaveLength(0);
  });

  it('hash is a 64-character hex string (SHA-256)', async () => {
    await fs.writeFile(path.join(tmpDir, 'check.luau'), 'content');

    const results = await loadActionSourcesAsync(tmpDir);

    expect(results[0].hash).toMatch(/^[0-9a-f]{64}$/);
  });
});
