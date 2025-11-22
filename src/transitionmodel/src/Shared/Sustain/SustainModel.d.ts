import { BaseObject } from '@quenty/baseobject';
import { Maid } from '@quenty/maid';

interface SustainModel extends BaseObject {
  SetPromiseSustain(
    sustainCallback?: (maid: Maid, doNotAnimate?: boolean) => Promise<void>
  ): void;
  SetIsSustained(isSustained: boolean, doNotAnimate?: boolean): void;
  Sustain(doNotAnimate?: boolean): void;
  Stop(doNotAnimate?: boolean): void;
  PromiseSustain(doNotAnimate?: boolean): Promise<void>;
}

interface SustainModelConstructor {
  readonly ClassName: 'SustainModel';
  new (): SustainModel;
}

export const SustainModel: SustainModelConstructor;
