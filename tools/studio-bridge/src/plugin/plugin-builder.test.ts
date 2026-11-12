import { describe, it, expect } from 'vitest';
import { fillPluginBuildTokens } from './plugin-builder.js';

const MODEL = [
  'local PLUGIN_VERSION = "{{PLUGIN_VERSION}}"',
  'local PORT = "{{PORT}}"',
  'local SESSION_ID = "{{SESSION_ID}}"',
  'local IS_EPHEMERAL = "{{EPHEMERAL}}" == "true"',
].join('\n');

describe('fillPluginBuildTokens', () => {
  it('fills every token, leaving the ones without a value empty', () => {
    const filled = fillPluginBuildTokens(MODEL, { PLUGIN_VERSION: 'abc123' });

    expect(filled).toContain('local PLUGIN_VERSION = "abc123"');
    expect(filled).toContain('local PORT = ""');
    expect(filled).not.toContain('{{');
  });

  it('throws when the model lacks a token', () => {
    expect(() => fillPluginBuildTokens('print(1)', {})).toThrow(
      'has no {{PLUGIN_VERSION}}'
    );
  });

  it('refuses a value that could escape its string', () => {
    expect(() => fillPluginBuildTokens(MODEL, { SESSION_ID: 'a"]]>' })).toThrow(
      'Invalid plugin build value for SESSION_ID'
    );
  });
});
