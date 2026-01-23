import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';

interface RogueHumanoidBase extends BaseObject {}

interface RogueHumanoidBaseConstructor {
  readonly ClassName: 'RogueHumanoidBase';
  new (humanoid: Humanoid, serviceBag: ServiceBag): RogueHumanoidBase;
}

export const RogueHumanoidBase: RogueHumanoidBaseConstructor;
