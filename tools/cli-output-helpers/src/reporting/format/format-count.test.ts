import { describe, it, expect } from 'vitest';
import { formatCount } from './format-count.js';

describe('formatCount', () => {
  it('uses the singular for one', () => {
    expect(formatCount(1, 'match', 'matches')).toBe('1 match');
  });

  it('uses the plural for zero and many', () => {
    expect(formatCount(0, 'match', 'matches')).toBe('0 matches');
    expect(formatCount(3, 'match', 'matches')).toBe('3 matches');
  });

  it('separates thousands', () => {
    expect(formatCount(1532, 'match', 'matches')).toBe('1,532 matches');
  });
});
