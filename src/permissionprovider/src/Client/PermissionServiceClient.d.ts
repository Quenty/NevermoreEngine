import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { PermissionProviderClient } from './Providers/PermissionProviderClient';

export interface PermissionServiceClient {
  readonly ServiceName: 'PermissionServiceClient';
  Init(serviceBag: ServiceBag): void;
  PromiseIsAdmin(): Promise<boolean>;
  PromisePermissionProvider(): Promise<PermissionProviderClient>;
  Destroy(): void;
}
