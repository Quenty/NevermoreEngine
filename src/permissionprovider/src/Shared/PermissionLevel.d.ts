export type PermissionLevel =
  (typeof PermissionLevel)[keyof typeof PermissionLevel];

export const PermissionLevel: Readonly<{
  ADMIN: 'admin';
  CREATOR: 'creator';
}>;
