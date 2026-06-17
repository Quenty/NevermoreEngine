import { BaseObject } from '@quenty/baseobject';
import { PlayerHumanoidBinder } from '@quenty/playerhumanoidbinder';
import { ServiceBag } from '@quenty/servicebag';

interface HumanoidSpeed extends BaseObject {
  SetDefaultSpeed(defaultSpeed: number): void;
  ApplySpeedMultiplier(multiplier: number): () => void;
  ApplySpeedAdditive(amount: number): () => void;
}

interface HumanoidSpeedConstructor {
  readonly ClassName: 'HumanoidSpeed';
  new (humanoid: Humanoid, serviceBag: ServiceBag): HumanoidSpeed;
}

export const HumanoidSpeed: PlayerHumanoidBinder<HumanoidSpeed>;
