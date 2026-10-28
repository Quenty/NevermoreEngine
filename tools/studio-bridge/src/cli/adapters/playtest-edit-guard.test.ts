import { describe, it, expect } from 'vitest';
import { assertNotEditingDuringPlaytest } from './cli-command-adapter.js';

function createSession(context: string, instanceId = 'test-place-3f9a') {
  return {
    context,
    info: { instanceId, placeName: 'test-place.rbxl', context },
  } as any;
}

function createConnection(contexts: string[]) {
  return {
    listSessions: () =>
      contexts.map((context) => ({ instanceId: 'test-place-3f9a', context })),
  } as any;
}

describe('assertNotEditingDuringPlaytest', () => {
  it('refuses to change Edit while its playtest runs', () => {
    expect(() =>
      assertNotEditingDuringPlaytest(
        createConnection(['edit', 'server', 'client']),
        createSession('edit')
      )
    ).toThrow(/playtest of 'test-place.rbxl' is running/);
  });

  it('allows changing Edit with no playtest running', () => {
    expect(() =>
      assertNotEditingDuringPlaytest(
        createConnection(['edit']),
        createSession('edit')
      )
    ).not.toThrow();
  });

  it('allows changing the playtest itself', () => {
    expect(() =>
      assertNotEditingDuringPlaytest(
        createConnection(['edit', 'server']),
        createSession('server')
      )
    ).not.toThrow();
  });

  it('ignores playtests of other Studios', () => {
    expect(() =>
      assertNotEditingDuringPlaytest(
        createConnection(['edit', 'server']),
        createSession('edit', 'other-place-1111')
      )
    ).not.toThrow();
  });
});
