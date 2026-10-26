import { describe, it, expect } from 'vitest';
import { partitionBySize } from './combined-project-generator.js';

describe('partitionBySize', () => {
  const identity = (n: number) => n;

  it('keeps everything in one group when it fits', () => {
    expect(partitionBySize([10, 20, 30], identity, 60)).toEqual([[10, 20, 30]]);
  });

  it('starts a new group, in order, before the budget would be exceeded', () => {
    expect(partitionBySize([40, 30, 20, 50, 10], identity, 60)).toEqual([
      [40],
      [30, 20],
      [50, 10],
    ]);
  });

  it('gives an item over the budget a group of its own', () => {
    expect(partitionBySize([10, 100, 10], identity, 60)).toEqual([
      [10],
      [100],
      [10],
    ]);
  });

  it('returns no groups for no items', () => {
    expect(partitionBySize([], identity, 60)).toEqual([]);
  });
});
