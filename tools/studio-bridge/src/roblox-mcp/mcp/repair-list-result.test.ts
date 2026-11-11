import { describe, expect, it } from 'vitest';
import { repairListResult } from './repair-list-result.js';

describe('repairListResult', () => {
  it('fills in the caching hints a 2026-07-28 list result left out', () => {
    expect(repairListResult({ resultType: 'complete', tools: [] })).toEqual({
      resultType: 'complete',
      tools: [],
      ttlMs: 0,
      cacheScope: 'private',
    });
  });

  it('keeps hints the server sent', () => {
    const result = {
      resultType: 'complete',
      tools: [],
      ttlMs: 500,
      cacheScope: 'shared',
    };

    expect(repairListResult(result)).toBe(result);
  });

  it('fills only the hint that is missing', () => {
    expect(
      repairListResult({ resultType: 'complete', prompts: [], ttlMs: 10 })
    ).toEqual({
      resultType: 'complete',
      prompts: [],
      ttlMs: 10,
      cacheScope: 'private',
    });
  });

  it('leaves an older protocol result alone', () => {
    const result = { tools: [] };

    expect(repairListResult(result)).toBe(result);
  });

  it('leaves a result that is not a list alone', () => {
    const result = { resultType: 'complete', content: [] };

    expect(repairListResult(result)).toBe(result);
  });

  it('passes non-objects through', () => {
    expect(repairListResult(undefined)).toBeUndefined();
    expect(repairListResult('text')).toBe('text');
  });
});
