import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { IdleExit } from './idle-exit.js';

describe('IdleExit', () => {
  let clients: number;
  let sessions: number;
  let onIdle: ReturnType<typeof vi.fn>;
  let idleExit: IdleExit;

  beforeEach(() => {
    vi.useFakeTimers();
    clients = 0;
    sessions = 1;
    onIdle = vi.fn();
    idleExit = new IdleExit({
      clientIdleMs: 10 * 60_000,
      noSessionMs: 2 * 60_000,
      getClientCount: () => clients,
      getSessionCount: () => sessions,
      onIdle,
    });
  });

  afterEach(() => {
    idleExit.stop();
    vi.useRealTimers();
  });

  it('exits after the idle timeout with no client activity, though Studio stays connected', () => {
    idleExit.start();

    vi.advanceTimersByTime(10 * 60_000 - 1);
    expect(onIdle).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1);
    expect(onIdle).toHaveBeenCalledWith('no CLI client activity for 10m0s');
  });

  it('restarts the idle timeout on client activity', () => {
    idleExit.start();
    vi.advanceTimersByTime(9 * 60_000);
    idleExit.noteClientActivity();

    vi.advanceTimersByTime(9 * 60_000);
    expect(onIdle).not.toHaveBeenCalled();
    vi.advanceTimersByTime(60_000);
    expect(onIdle).toHaveBeenCalledTimes(1);
  });

  it('never exits while a client is connected', () => {
    clients = 1;
    idleExit.start();

    vi.advanceTimersByTime(60 * 60_000);
    expect(onIdle).not.toHaveBeenCalled();

    clients = 0;
    vi.advanceTimersByTime(10 * 60_000);
    expect(onIdle).toHaveBeenCalledTimes(1);
  });

  it('exits sooner with no Studio session connected', () => {
    sessions = 0;
    idleExit.start();

    vi.advanceTimersByTime(2 * 60_000);
    expect(onIdle).toHaveBeenCalledWith('no Studio session connected for 2m0s');
  });

  it('counts the time without a session from when the last one left', () => {
    idleExit.start();
    vi.advanceTimersByTime(5 * 60_000);
    sessions = 0;
    idleExit.noteSessionsChanged();
    idleExit.noteClientActivity();

    vi.advanceTimersByTime(2 * 60_000 - 1);
    expect(onIdle).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1);
    expect(onIdle).toHaveBeenCalledWith('no Studio session connected for 2m0s');
  });

  it('stops counting the time without a session once one connects', () => {
    sessions = 0;
    idleExit.start();
    vi.advanceTimersByTime(60_000);
    sessions = 1;
    idleExit.noteSessionsChanged();

    vi.advanceTimersByTime(5 * 60_000);
    expect(onIdle).not.toHaveBeenCalled();
  });

  it('exits once', () => {
    sessions = 0;
    idleExit.start();

    vi.advanceTimersByTime(60 * 60_000);
    expect(onIdle).toHaveBeenCalledTimes(1);
  });
});
