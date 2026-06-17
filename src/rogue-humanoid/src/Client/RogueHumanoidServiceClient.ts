import { ServiceBag } from '@quenty/servicebag';

export interface RogueHumanoidServiceClient {
  Init(serviceBag: ServiceBag): void;
}
