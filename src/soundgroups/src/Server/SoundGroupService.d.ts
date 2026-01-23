import { ServiceBag } from '@quenty/servicebag';

export interface SoundGroupService {
  readonly ServiceName: 'SoundGroupService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  Destroy(): void;
}
