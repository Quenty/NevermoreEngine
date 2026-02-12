import { ServiceBag } from '@quenty/servicebag';

export interface SettingsInputKeyMapServiceClient {
  readonly ServiceName: 'SettingsInputKeyMapServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  Destroy(): void;
}
