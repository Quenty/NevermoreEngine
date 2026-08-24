import { PermissionLevel } from './PermissionLevel';

export namespace PermissionLevelUtils {
  function isPermissionLevel(value: unknown): value is PermissionLevel;
}
