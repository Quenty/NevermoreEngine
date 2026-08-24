import { ServiceBag } from '@quenty/servicebag';

export interface ScoredActionService {
  Init(serviceBag: ServiceBag): void;
}
