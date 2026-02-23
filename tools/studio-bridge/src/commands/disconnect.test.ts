/**
 * Unit tests for the disconnect command handler.
 */

import { describe, it, expect } from 'vitest';
import { disconnectHandler } from './disconnect.js';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('disconnectHandler', () => {
  it('returns a summary message', () => {
    const result = disconnectHandler();

    expect(result.summary).toBe('Disconnected from session.');
  });

  it('returns an object with summary field', () => {
    const result = disconnectHandler();

    expect(result).toHaveProperty('summary');
    expect(typeof result.summary).toBe('string');
  });
});
