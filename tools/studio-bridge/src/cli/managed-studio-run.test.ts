import { describe, it, expect } from 'vitest';
import { EventEmitter } from 'events';
import { waitForLaunchedSessionAsync } from './managed-studio-run.js';

function createConnection() {
  const emitter = new EventEmitter();
  const sessions: Array<{
    sessionId: string;
    launchId?: string;
    context: string;
  }> = [];
  const connection = Object.assign(emitter, {
    listSessions: () => sessions,
    getSession: (id: string) =>
      sessions.some((s) => s.sessionId === id) ? { id } : undefined,
  });
  return {
    connection: connection as any,
    addSession(session: {
      sessionId: string;
      launchId?: string;
      context: string;
    }) {
      sessions.push(session);
      emitter.emit('session-connected');
    },
  };
}

describe('waitForLaunchedSessionAsync', () => {
  it('resolves with the edit session carrying the launch id', async () => {
    const { connection, addSession } = createConnection();
    const promise = waitForLaunchedSessionAsync(connection, 'launch-1', 1_000);

    addSession({ sessionId: 'other-edit', context: 'edit' });
    addSession({
      sessionId: 'run-server',
      launchId: 'launch-1',
      context: 'server',
    });
    addSession({
      sessionId: 'run-edit',
      launchId: 'launch-1',
      context: 'edit',
    });

    await expect(promise).resolves.toEqual({ id: 'run-edit' });
  });

  it('resolves right away when the session already connected', async () => {
    const { connection, addSession } = createConnection();
    addSession({
      sessionId: 'run-edit',
      launchId: 'launch-1',
      context: 'edit',
    });

    await expect(
      waitForLaunchedSessionAsync(connection, 'launch-1', 1_000)
    ).resolves.toEqual({ id: 'run-edit' });
  });

  it('rejects when the launched Studio never connects', async () => {
    const { connection, addSession } = createConnection();
    const promise = waitForLaunchedSessionAsync(connection, 'launch-1', 50);

    addSession({ sessionId: 'other-edit', context: 'edit' });

    await expect(promise).rejects.toThrow(/did not connect/);
  });
});
