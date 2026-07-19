import { ServiceBag } from '@quenty/servicebag';
import { RogueHumanoidBase } from '../Shared/RogueHumanoidBase';
import { Binder } from '@quenty/binder';

interface RogueHumanoidClient extends RogueHumanoidBase {}

interface RogueHumanoidClientConstructor {
  readonly ClassName: 'RogueHumanoidClient';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RogueHumanoidClient;
}

export const RogueHumanoidClient: Binder<RogueHumanoidClient>;
