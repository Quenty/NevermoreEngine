/**
 * Unit tests for the terminal dot-command dispatcher.
 */

import { describe, it, expect, vi } from 'vitest';
import {
  TerminalDotCommands,
  getBridgeCommandNames,
  getAllCommandNames,
} from './terminal-dot-commands.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockConnection(options?: {
  sessions?: Array<{ sessionId: string; context: string; placeName: string }>;
}) {
  const sessions = options?.sessions ?? [];

  return {
    listSessions: vi.fn().mockReturnValue(
      sessions.map((s) => ({
        sessionId: s.sessionId,
        placeName: s.placeName,
        context: s.context,
        state: 'Edit',
        pluginVersion: '1.0.0',
        capabilities: ['execute'],
        connectedAt: new Date(),
        origin: 'user',
        instanceId: 'inst-1',
        placeId: 123,
        gameId: 456,
      })),
    ),
    resolveSession: vi.fn().mockImplementation(async (sessionId: string) => {
      const session = sessions.find((s) => s.sessionId === sessionId);
      if (!session) {
        throw new Error(`Session '${sessionId}' not found`);
      }
      return {
        info: session,
      };
    }),
    getSession: vi.fn().mockImplementation((sessionId: string) => {
      const session = sessions.find((s) => s.sessionId === sessionId);
      if (!session) return undefined;
      return createMockSession(session);
    }),
  } as any;
}

function createMockSession(info?: {
  sessionId?: string;
  context?: string;
  placeName?: string;
}) {
  return {
    info: {
      sessionId: info?.sessionId ?? 'test-session',
      context: info?.context ?? 'edit',
      placeName: info?.placeName ?? 'TestPlace',
    },
    queryStateAsync: vi.fn().mockResolvedValue({
      state: 'Edit',
      placeId: 123,
      placeName: 'TestPlace',
      gameId: 456,
    }),
    captureScreenshotAsync: vi.fn().mockResolvedValue({
      data: 'base64data',
      format: 'png',
      width: 800,
      height: 600,
    }),
    queryLogsAsync: vi.fn().mockResolvedValue({
      entries: [{ level: 'Print', body: 'Hello', timestamp: Date.now() }],
      total: 1,
      bufferCapacity: 100,
    }),
    queryDataModelAsync: vi.fn().mockResolvedValue({
      instance: {
        name: 'Workspace',
        className: 'Workspace',
        path: 'game.Workspace',
        children: [],
      },
    }),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('TerminalDotCommands', () => {
  describe('isBridgeCommand', () => {
    it('recognizes all bridge commands', () => {
      const dispatcher = new TerminalDotCommands();

      for (const name of getBridgeCommandNames()) {
        expect(dispatcher.isBridgeCommand(name)).toBe(true);
      }
    });

    it('does not recognize built-in commands', () => {
      const dispatcher = new TerminalDotCommands();

      expect(dispatcher.isBridgeCommand('.help')).toBe(false);
      expect(dispatcher.isBridgeCommand('.exit')).toBe(false);
      expect(dispatcher.isBridgeCommand('.clear')).toBe(false);
      expect(dispatcher.isBridgeCommand('.run')).toBe(false);
    });

    it('does not recognize unknown commands', () => {
      const dispatcher = new TerminalDotCommands();

      expect(dispatcher.isBridgeCommand('.unknown')).toBe(false);
      expect(dispatcher.isBridgeCommand('.foo')).toBe(false);
    });
  });

  describe('dispatchAsync', () => {
    it('returns handled=false for unknown commands', async () => {
      const dispatcher = new TerminalDotCommands();
      const result = await dispatcher.dispatchAsync('.unknown');

      expect(result.handled).toBe(false);
    });

    it('returns error when no connection for .sessions', async () => {
      const dispatcher = new TerminalDotCommands();
      const result = await dispatcher.dispatchAsync('.sessions');

      expect(result.handled).toBe(true);
      expect(result.error).toContain('No bridge connection');
    });

    it('dispatches .sessions to listSessionsHandlerAsync', async () => {
      const conn = createMockConnection({
        sessions: [{ sessionId: 's1', context: 'edit', placeName: 'Place1' }],
      });
      const dispatcher = new TerminalDotCommands(conn);
      const result = await dispatcher.dispatchAsync('.sessions');

      expect(result.handled).toBe(true);
      expect(result.output).toContain('1 session(s)');
    });

    it('returns error when .connect has no session ID', async () => {
      const conn = createMockConnection();
      const dispatcher = new TerminalDotCommands(conn);
      const result = await dispatcher.dispatchAsync('.connect');

      expect(result.handled).toBe(true);
      expect(result.error).toContain('Usage');
    });

    it('dispatches .connect with session ID', async () => {
      const conn = createMockConnection({
        sessions: [{ sessionId: 'abc-123', context: 'edit', placeName: 'TestPlace' }],
      });
      const dispatcher = new TerminalDotCommands(conn);
      const result = await dispatcher.dispatchAsync('.connect abc-123');

      expect(result.handled).toBe(true);
      expect(result.output).toContain('abc-123');
      expect(dispatcher.activeSession).toBeDefined();
    });

    it('.connect sets the active session', async () => {
      const conn = createMockConnection({
        sessions: [{ sessionId: 'xyz-789', context: 'edit', placeName: 'Place' }],
      });
      const dispatcher = new TerminalDotCommands(conn);

      expect(dispatcher.activeSession).toBeUndefined();

      await dispatcher.dispatchAsync('.connect xyz-789');

      expect(dispatcher.activeSession).toBeDefined();
    });

    it('.disconnect clears the active session', async () => {
      const dispatcher = new TerminalDotCommands();
      dispatcher.activeSession = createMockSession();

      expect(dispatcher.activeSession).toBeDefined();

      const result = await dispatcher.dispatchAsync('.disconnect');

      expect(result.handled).toBe(true);
      expect(result.output).toContain('Disconnected');
      expect(dispatcher.activeSession).toBeUndefined();
    });

    it('returns error when .state has no active session', async () => {
      const dispatcher = new TerminalDotCommands();
      const result = await dispatcher.dispatchAsync('.state');

      expect(result.handled).toBe(true);
      expect(result.error).toContain('No active session');
    });

    it('dispatches .state to queryStateHandlerAsync', async () => {
      const dispatcher = new TerminalDotCommands();
      dispatcher.activeSession = createMockSession();

      const result = await dispatcher.dispatchAsync('.state');

      expect(result.handled).toBe(true);
      expect(result.output).toContain('Edit');
      expect(result.output).toContain('TestPlace');
    });

    it('dispatches .screenshot to captureScreenshotHandlerAsync', async () => {
      const dispatcher = new TerminalDotCommands();
      dispatcher.activeSession = createMockSession();

      const result = await dispatcher.dispatchAsync('.screenshot');

      expect(result.handled).toBe(true);
      expect(result.output).toContain('Screenshot captured');
      expect(result.output).toContain('800x600');
    });

    it('dispatches .logs to queryLogsHandlerAsync', async () => {
      const dispatcher = new TerminalDotCommands();
      dispatcher.activeSession = createMockSession();

      const result = await dispatcher.dispatchAsync('.logs');

      expect(result.handled).toBe(true);
      expect(result.output).toContain('1 entries');
    });

    it('returns error when .query has no path', async () => {
      const dispatcher = new TerminalDotCommands();
      dispatcher.activeSession = createMockSession();

      const result = await dispatcher.dispatchAsync('.query');

      expect(result.handled).toBe(true);
      expect(result.error).toContain('Usage');
    });

    it('dispatches .query with path to queryDataModelHandlerAsync', async () => {
      const dispatcher = new TerminalDotCommands();
      dispatcher.activeSession = createMockSession();

      const result = await dispatcher.dispatchAsync('.query game.Workspace');

      expect(result.handled).toBe(true);
      expect(result.output).toContain('Workspace');
    });
  });

  describe('generateHelpText', () => {
    it('includes all command names', () => {
      const dispatcher = new TerminalDotCommands();
      const help = dispatcher.generateHelpText();

      for (const name of getAllCommandNames()) {
        expect(help).toContain(name);
      }
    });

    it('includes keybinding section', () => {
      const dispatcher = new TerminalDotCommands();
      const help = dispatcher.generateHelpText();

      expect(help).toContain('Keybindings');
      expect(help).toContain('Ctrl+Enter');
      expect(help).toContain('Ctrl+C');
    });
  });

  describe('getBridgeCommandNames', () => {
    it('returns expected bridge commands', () => {
      const names = getBridgeCommandNames();

      expect(names).toContain('.sessions');
      expect(names).toContain('.connect');
      expect(names).toContain('.disconnect');
      expect(names).toContain('.state');
      expect(names).toContain('.screenshot');
      expect(names).toContain('.logs');
      expect(names).toContain('.query');
    });
  });

  describe('getAllCommandNames', () => {
    it('includes both built-in and bridge commands', () => {
      const names = getAllCommandNames();

      // Built-in
      expect(names).toContain('.help');
      expect(names).toContain('.exit');
      expect(names).toContain('.clear');
      expect(names).toContain('.run');

      // Bridge
      expect(names).toContain('.sessions');
      expect(names).toContain('.state');
    });
  });
});
