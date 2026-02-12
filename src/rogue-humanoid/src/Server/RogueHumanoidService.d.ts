import { ServiceBag } from '@quenty/servicebag';

export interface RogueHumanoidService {
  readonly ServiceName: 'RogueHumanoidService';
  Init(serviceBag: ServiceBag): void;
}
