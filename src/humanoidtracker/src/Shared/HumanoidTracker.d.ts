import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { Signal } from '@quenty/signal';
import { ValueObject } from '@quenty/valueobject';

interface HumanoidTracker extends BaseObject {
  HumanoidDied: Signal<Humanoid>;
  Humanoid: ValueObject<Humanoid | undefined>;
  AliveHumanoid: ValueObject<Humanoid | undefined>;
  PromiseNextHumanoid(): Promise<Humanoid>;
}

interface HumanoidTrackerConstructor {
  readonly ClassName: 'HumanoidTracker';
  new (player: Player): HumanoidTracker;
}

export const HumanoidTracker: HumanoidTrackerConstructor;
