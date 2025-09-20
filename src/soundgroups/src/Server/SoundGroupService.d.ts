import { ServiceBag } from '@quenty/servicebag';

export interface SoundGroupService {
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  Destroy(): void;
}
