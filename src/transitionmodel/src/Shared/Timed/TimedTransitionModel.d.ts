import { BasicPane } from '@quenty/basicpane';
import { Observable } from '@quenty/rx';

interface TimedTransitionModel extends BasicPane {
  SetTransitionTime(transitionTime: number): void;
  IsShowingComplete(): boolean;
  IsHidingComplete(): boolean;
  ObserveIsShowingComplete(): Observable<boolean>;
  ObserveIsHidingComplete(): Observable<boolean>;
  BindToPaneVisibility(pane: BasicPane): () => void;
  ObserveRenderStepped(): Observable<number>;
  Observe(): Observable<number>;
  PromiseShow(doNotAnimate?: boolean): Promise<void>;
  PromiseHide(doNotAnimate?: boolean): Promise<void>;
  PromiseToggle(doNotAnimate?: boolean): Promise<void>;
}

interface TimedTransitionModelConstructor {
  readonly ClassName: 'TimedTransitionModel';
  new (transitionTime?: number): TimedTransitionModel;
}

export const TimedTransitionModel: TimedTransitionModelConstructor;
