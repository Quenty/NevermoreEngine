import { ServiceBag } from '@quenty/servicebag';
import { RogueHumanoidBase } from '../Shared/RogueHumanoidBase';
import { Binder } from '@quenty/binder';

interface RogueHumanoid extends RogueHumanoidBase {}

interface RogueHumanoidConstructor {
  readonly ClassName: 'RogueHumanoid';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RogueHumanoid;
}

export const RogueHumanoid: Binder<RogueHumanoid>;
