import { Promise } from '@quenty/promise';
import { CmdrClient } from '../Shared/CmdrTypes';

export interface CmdrServiceClient {
  readonly ServiceName: 'CmdrServiceClient';
  Start(): void;
  PromiseCmdr(): Promise<CmdrClient>;
  Destroy(): void;
}
