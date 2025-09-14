import { Promise } from '@quenty/promise';

export interface ResetServiceClient {
  Init(): void;
  PromiseResetCharacter(): Promise;
  Destroy(): void;
}
