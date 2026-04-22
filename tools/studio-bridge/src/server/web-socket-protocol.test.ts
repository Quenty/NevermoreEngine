import { describe, it, expect } from 'vitest';
import { encodeMessage, decodePluginMessage } from './web-socket-protocol.js';

describe('encodeMessage', () => {
  it('encodes a welcome message', () => {
    const json = encodeMessage({
      type: 'welcome',
      sessionId: 'abc-123',
      payload: { sessionId: 'abc-123' },
    });
    const parsed = JSON.parse(json);
    expect(parsed).toEqual({
      type: 'welcome',
      sessionId: 'abc-123',
      payload: { sessionId: 'abc-123' },
    });
  });

  it('encodes a shutdown message', () => {
    const json = encodeMessage({ type: 'shutdown', sessionId: 'abc-123', payload: {} });
    const parsed = JSON.parse(json);
    expect(parsed).toEqual({ type: 'shutdown', sessionId: 'abc-123', payload: {} });
  });

  it('encodes an execute message', () => {
    const json = encodeMessage({
      type: 'execute',
      sessionId: 'abc-123',
      payload: { script: 'print("hi")' },
    });
    const parsed = JSON.parse(json);
    expect(parsed).toEqual({
      type: 'execute',
      sessionId: 'abc-123',
      payload: { script: 'print("hi")' },
    });
  });
});

describe('decodePluginMessage', () => {
  describe('hello', () => {
    it('decodes a valid hello message', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'hello',
          sessionId: 'test-session',
          payload: { sessionId: 'test-session' },
        })
      );
      expect(msg).toEqual({
        type: 'hello',
        sessionId: 'test-session',
        payload: { sessionId: 'test-session' },
      });
    });

    it('returns null for hello without sessionId in payload', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'hello',
          sessionId: 'test-session',
          payload: {},
        })
      );
      expect(msg).toBeNull();
    });

    it('returns null for hello without top-level sessionId', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'hello',
          payload: { sessionId: 'test-session' },
        })
      );
      expect(msg).toBeNull();
    });
  });

  describe('output', () => {
    it('decodes a valid output message with multiple entries', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'output',
          sessionId: 'test-session',
          payload: {
            messages: [
              { level: 'Print', body: 'Hello world' },
              { level: 'Warning', body: 'Watch out' },
            ],
          },
        })
      );
      expect(msg).toEqual({
        type: 'output',
        sessionId: 'test-session',
        payload: {
          messages: [
            { level: 'Print', body: 'Hello world' },
            { level: 'Warning', body: 'Watch out' },
          ],
        },
      });
    });

    it('filters out invalid entries in messages array', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'output',
          sessionId: 'test-session',
          payload: {
            messages: [
              { level: 'Print', body: 'valid' },
              { level: 123, body: 'bad level' },
              'not an object',
              null,
            ],
          },
        })
      );
      expect(msg).toEqual({
        type: 'output',
        sessionId: 'test-session',
        payload: {
          messages: [{ level: 'Print', body: 'valid' }],
        },
      });
    });

    it('returns null for output without messages array', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'output',
          sessionId: 'test-session',
          payload: { messages: 'not-an-array' },
        })
      );
      expect(msg).toBeNull();
    });

    it('returns null for output without top-level sessionId', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'output',
          payload: { messages: [{ level: 'Print', body: 'test' }] },
        })
      );
      expect(msg).toBeNull();
    });
  });

  describe('scriptComplete', () => {
    it('decodes a successful scriptComplete', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'scriptComplete',
          sessionId: 'test-session',
          payload: { success: true },
        })
      );
      expect(msg).toEqual({
        type: 'scriptComplete',
        sessionId: 'test-session',
        payload: { success: true, error: undefined },
      });
    });

    it('decodes a failed scriptComplete with error', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'scriptComplete',
          sessionId: 'test-session',
          payload: { success: false, error: 'Script errored' },
        })
      );
      expect(msg).toEqual({
        type: 'scriptComplete',
        sessionId: 'test-session',
        payload: { success: false, error: 'Script errored' },
      });
    });

    it('returns null if success is not boolean', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'scriptComplete',
          sessionId: 'test-session',
          payload: { success: 'yes' },
        })
      );
      expect(msg).toBeNull();
    });

    it('returns null for scriptComplete without top-level sessionId', () => {
      const msg = decodePluginMessage(
        JSON.stringify({
          type: 'scriptComplete',
          payload: { success: true },
        })
      );
      expect(msg).toBeNull();
    });
  });

  describe('malformed messages', () => {
    it('returns null for invalid JSON', () => {
      expect(decodePluginMessage('not json')).toBeNull();
    });

    it('returns null for non-object JSON', () => {
      expect(decodePluginMessage('"just a string"')).toBeNull();
    });

    it('returns null for missing type', () => {
      expect(decodePluginMessage(JSON.stringify({ sessionId: 's', payload: {} }))).toBeNull();
    });

    it('returns null for missing payload', () => {
      expect(decodePluginMessage(JSON.stringify({ type: 'hello', sessionId: 's' }))).toBeNull();
    });

    it('returns null for missing sessionId', () => {
      expect(
        decodePluginMessage(
          JSON.stringify({ type: 'hello', payload: { sessionId: 's' } })
        )
      ).toBeNull();
    });

    it('returns null for unknown message type', () => {
      expect(
        decodePluginMessage(
          JSON.stringify({
            type: 'unknown',
            sessionId: 'test',
            payload: {},
          })
        )
      ).toBeNull();
    });
  });
});
