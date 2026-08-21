import { describe, expect, it } from 'vitest';

import { chunkSlugMap } from './batch-script-job-context.js';

function buildSlugMap(count: number): Map<string, string> {
  return new Map(
    Array.from({ length: count }, (_, i) => [`pkg${i}`, `slug${i}`])
  );
}

describe('chunkSlugMap', () => {
  it('leaves a batch that already fits alone', () => {
    const slugMap = buildSlugMap(8);

    const chunks = chunkSlugMap(slugMap, 16);

    expect(chunks).toHaveLength(1);
    expect(chunks[0]).toBe(slugMap);
  });

  it('splits a batch too large for one task log', () => {
    // 73 packages in one task lost the first 14 to the log window.
    const chunks = chunkSlugMap(buildSlugMap(73), 16);

    expect(chunks).toHaveLength(5);
    expect(chunks.at(-1)?.size).toBe(9);
  });

  it('covers every package exactly once', () => {
    const chunks = chunkSlugMap(buildSlugMap(73), 16);

    const seen = chunks.flatMap((chunk) => [...chunk.keys()]);

    expect(seen).toHaveLength(73);
    expect(new Set(seen).size).toBe(73);
  });

  it('treats a non-positive size as no chunking', () => {
    const slugMap = buildSlugMap(20);

    expect(chunkSlugMap(slugMap, 0)).toEqual([slugMap]);
  });
});
