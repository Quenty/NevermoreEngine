import { BaseObject } from '@quenty/baseobject';
import { PermissionProviderConfig } from '../PermissionProviderUtils';
import { PermissionLevel } from '../../Shared/PermissionLevel';
import { Promise } from '@quenty/promise';

interface BasePermissionProvider extends BaseObject {
  Start(): void;
  PromiseIsPermissionLevel(
    player: Player,
    permissionLevel: PermissionLevel
  ): Promise<boolean>;
  IsPermissionLevel(player: Player, permissionLevel: PermissionLevel): boolean;
  PromiseIsCreator(player: Player): Promise<boolean>;
  PromiseIsAdmin(player: Player): Promise<boolean>;
  IsCreator(player: Player): boolean;
  IsAdmin(player: Player): boolean;
}

interface BasePermissionProviderConstructor {
  readonly ClassName: 'BasePermissionProvider';
  new (config: PermissionProviderConfig): BasePermissionProvider;
}

export const BasePermissionProvider: BasePermissionProviderConstructor;
