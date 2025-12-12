import { ServiceBag } from '@quenty/servicebag';
import { PermissionProviderConfig } from './PermissionProviderUtils';
import { Promise } from '@quenty/promise';
import { BasePermissionProvider } from './Providers/BasePermissionProvider';
import { PermissionLevel } from '../Shared/PermissionLevel';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';

export interface PermissionService {
  readonly ServiceName: 'PermissionService';
  Init(serviceBag: ServiceBag): void;
  SetProviderFromConfig(config: PermissionProviderConfig): void;
  Start(): void;
  PromisePermissionProvider(): Promise<BasePermissionProvider>;
  PromiseIsAdmin(player: Player): Promise<boolean>;
  PromiseIsCreator(player: Player): Promise<boolean>;
  PromiseIsPermissionLevel(
    player: Player,
    permissionLevel: PermissionLevel
  ): Promise<boolean>;
  ObservePermissionedPlayersBrio(
    permissionLevel: PermissionLevel
  ): Observable<Brio<Player>>;
  Destroy(): void;
}
