import { ServiceBag } from '@quenty/servicebag';

export interface SettingsInputKeyMapService {
  readonly ServiceName: 'SettingsInputKeyMapService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  Destroy(): void;
}
