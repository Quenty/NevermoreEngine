import { ServiceBag } from '@quenty/servicebag';

export interface SettingsCmdrService {
  readonly ServiceName: 'SettingsCmdrService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  Destroy(): void;
}
