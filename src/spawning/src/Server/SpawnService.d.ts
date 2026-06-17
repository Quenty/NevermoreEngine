import { Binder } from '@quenty/binder';
import { ServiceBag } from '@quenty/servicebag';

export interface SpawnService {
  readonly ServiceName: 'SpawnService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  AddSpawnerBinder(spawnerBinder: Binder<unknown>): void;
  Regenerate(): void;
  Update(): void;
  Destroy(): void;
}
