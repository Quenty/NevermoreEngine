import { GroupRankConfig } from '../PermissionProviderUtils';
import { BasePermissionProvider } from './BasePermissionProvider';

interface GroupPermissionProvider extends BasePermissionProvider {}

interface GroupPermissionProviderConstructor {
  readonly ClassName: 'GroupPermissionProvider';
  new (config: GroupRankConfig): GroupPermissionProvider;
}

export const GroupPermissionProvider: GroupPermissionProviderConstructor;
