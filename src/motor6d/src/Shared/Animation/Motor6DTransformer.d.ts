import { BaseObject } from '@quenty/baseobject';
import { Signal } from '@quenty/signal';

interface Motor6DTransformer extends BaseObject {
  Finished: Signal;
  Transform(getBelow: () => CFrame): CFrame | undefined;
  FireFinished(): void;
}

interface Motor6DTransformerConstructor {
  readonly ClassName: 'Motor6DTransformer';
  new (): Motor6DTransformer;
}

export const Motor6DTransformer: Motor6DTransformerConstructor;
