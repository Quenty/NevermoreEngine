import { ServiceBag } from '@quenty/servicebag';

export interface RagdollServiceClient {
  Init(serviceBag: ServiceBag): void;
  SetScreenShakeEnabled(value: boolean): void;
  GetScreenShakeEnabled(): boolean;
}
