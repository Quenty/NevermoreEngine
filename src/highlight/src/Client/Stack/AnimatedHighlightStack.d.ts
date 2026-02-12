import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { AnimatedHighlightModel } from './AnimatedHighlightModel';

interface AnimatedHighlightStack extends BaseObject {
  Done: Signal;
  Destroying: Signal;

  SetPropertiesFrom(source: AnimatedHighlightStack): void;
  ObserveHasEntries(): Observable<boolean>;
  GetHandle(observeScore: Observable<number>): AnimatedHighlightModel;
}

interface AnimatedHighlightStackConstructor {
  readonly ClassName: 'AnimatedHighlightStack';
  new (): AnimatedHighlightStack;

  isAnimatedHighlightStack: (value: unknown) => value is AnimatedHighlightStack;
}

export const AnimatedHighlightStack: AnimatedHighlightStackConstructor;
