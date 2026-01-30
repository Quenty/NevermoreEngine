import { BaseObject } from '@quenty/baseobject';
import { Binder } from '@quenty/binder';

interface HumanoidSpeedClient extends BaseObject {
  GetPlayer(): Player | undefined;
}

interface HumanoidSpeedClientConstructor {
  readonly ClassName: 'HumanoidSpeedClient';
  new (humanoid: Humanoid): HumanoidSpeedClient;
}

export const HumanoidSpeedClient: Binder<HumanoidSpeedClient>;
