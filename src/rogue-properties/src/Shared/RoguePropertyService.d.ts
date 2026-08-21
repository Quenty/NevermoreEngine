import { ServiceBag } from '@quenty/servicebag';

export interface RoguePropertyService {
  readonly ServiceName: 'RoguePropertyService';
  Init(serviceBag: ServiceBag): void;
  CanInitializeProperties(): boolean;
  Destroy(): void;
}
