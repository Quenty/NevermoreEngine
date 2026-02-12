import { ServiceBag } from '@quenty/servicebag';
import { RogueHumanoidBase } from '../Shared/RogueHumanoidBase';
import { PlayerHumanoidBinder } from '@quenty/playerhumanoidbinder';

interface RogueHumanoid extends RogueHumanoidBase {}

interface RogueHumanoidConstructor {
  readonly ClassName: 'RogueHumanoid';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RogueHumanoid;
}

export const RogueHumanoid: PlayerHumanoidBinder<RogueHumanoid>;
