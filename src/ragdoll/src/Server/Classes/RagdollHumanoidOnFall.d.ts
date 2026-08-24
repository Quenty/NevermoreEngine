import { ServiceBag } from '@quenty/servicebag';
import { PlayerHumanoidBinder } from '@quenty/playerhumanoidbinder';
import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';

interface RagdollHumanoidOnFall extends BaseObject {
  ObserveIsFalling(): Observable<boolean>;
}

interface RagdollHumanoidOnFallConstructor {
  readonly ClassName: 'RagdollHumanoidOnFall';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RagdollHumanoidOnFall;
}

export const RagdollHumanoidOnFall: PlayerHumanoidBinder<RagdollHumanoidOnFall>;
