import { SingleUserConfig } from '../PermissionProviderUtils';
import { BasePermissionProvider } from './BasePermissionProvider';

interface CreatorPermissionProvider extends BasePermissionProvider {}

interface CreatorPermissionProviderConstructor {
  readonly ClassName: 'CreatorPermissionProvider';
  new (config: SingleUserConfig): CreatorPermissionProvider;
}

export const CreatorPermissionProvider: CreatorPermissionProviderConstructor;
