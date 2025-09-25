import { Promise } from '@quenty/promise';

export interface ResetServiceClient {
  readonly ServiceName: 'ResetServiceClient';
  Init(): void;
  PromiseResetCharacter(): Promise;
  Destroy(): void;
}
