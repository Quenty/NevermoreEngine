/**
 * Every plugin registers as `Edit`, since it cannot see a playtest from the
 * edit DataModel. The bridge can: a playtest's server and client connect as
 * sessions of the same instance. Their place is a copy named "Game", so
 * they take the edit session's place name too.
 */

import type { SessionInfo, StudioState } from '../types.js';

export function annotateInstanceState(sessions: SessionInfo[]): SessionInfo[] {
  const byInstance = new Map<string, SessionInfo[]>();
  for (const session of sessions) {
    const group = byInstance.get(session.instanceId) ?? [];
    group.push(session);
    byInstance.set(session.instanceId, group);
  }

  return sessions.map((session) => {
    const group = byInstance.get(session.instanceId)!;
    const hasServer = group.some((s) => s.context === 'server');
    const hasClient = group.some((s) => s.context === 'client');
    const edit = group.find((s) => s.context === 'edit');

    const state: StudioState = hasServer
      ? hasClient
        ? 'Play'
        : 'Run'
      : session.state;
    const placeName =
      session.context !== 'edit' && edit ? edit.placeName : session.placeName;

    return { ...session, state, placeName };
  });
}
