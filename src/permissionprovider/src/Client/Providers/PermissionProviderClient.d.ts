import { Promise } from '@quenty/promise';

interface PermissionProviderClient {
  PromiseIsAdmin(): Promise<boolean>;
}

interface PermissionProviderClientConstructor {
  readonly ClassName: 'PermissionProviderClient';
  new (remoteFunctionName: string): PermissionProviderClient;
}

export const PermissionProviderClient: PermissionProviderClientConstructor;
