import { ServiceBag } from '@quenty/servicebag';

export interface RoguePropertyService {
  Init(serviceBag: ServiceBag): void;
  CanInitializeProperties(): boolean;
  Destroy(): void;
}
