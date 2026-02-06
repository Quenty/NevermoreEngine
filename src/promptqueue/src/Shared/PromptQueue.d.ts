import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { TransitionModel } from '@quenty/transitionmodel';

interface PromptQueue extends BaseObject {
  Queue(transitionModel: TransitionModel): Promise;
  HasItems(): boolean;
  Clear(doNotAnimate?: boolean): void;
  HideCurrent(doNotAnimate?: boolean): Promise;
  IsShowing(): boolean;
  ObserveIsShowing(): Observable<boolean>;
}

interface PromptQueueConstructor {
  readonly ClassName: 'PromptQueue';
  new (): PromptQueue;
}

export const PromptQueue: PromptQueueConstructor;
