export const TemplateReplicationModes: Readonly<{
  CLIENT: 'client';
  SHARED: 'shared';
  SERVER: 'server';
}>;

export type TemplateReplicationMode = 'client' | 'server' | 'shared';
