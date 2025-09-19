import { ServiceBag } from '@quenty/servicebag';

export interface ClipCharactersService {
  Init(serviceBag: ServiceBag): void;
  Destroy(): void;
}
