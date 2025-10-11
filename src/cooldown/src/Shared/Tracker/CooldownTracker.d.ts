import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { ValueObject } from '@quenty/valueobject';
import { CooldownShared } from '../Binders/CooldownShared';
import { CooldownTrackerModel } from '../Model/CooldownTrackerModel';

interface CooldownTracker extends BaseObject {
  CurrentCooldown: ValueObject<CooldownShared | undefined>;
  GetCooldownTrackerModel(): CooldownTrackerModel;
  IsCoolingDown(): boolean;
}

interface CooldownTrackerConstructor {
  readonly ClassName: 'CooldownTracker';
  new (serviceBag: ServiceBag, parent: Instance): CooldownTracker;
}

export const CooldownTracker: CooldownTrackerConstructor;
