import { SimpleEnum } from '@quenty/enums';

export type PermissionLevel =
  (typeof PermissionLevel)[keyof typeof PermissionLevel];

export const PermissionLevel: SimpleEnum<{
  ADMIN: 'admin';
  CREATOR: 'creator';
}>;
