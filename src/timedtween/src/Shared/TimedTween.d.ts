import { BasicPane } from '@quenty/basicpane';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

interface TimedTween extends BasicPane {
  SetTransitionTime(transitionTime: number | Observable<number>): void;
  GetTransitionTime(): number;
  ObserveTransitionTime(): Observable<number>;
  ObserveRenderStepped(): Observable<number>;
  ObserveOnSignal(signal: Signal): Observable<number>;
  Observe(): Observable<number>;
  PromiseFinished(): Promise;
}

interface TimedTweenConstructor {
  readonly ClassName: 'TimedTween';
  new (transitionTime?: number): TimedTween;
}

export const TimedTween: TimedTweenConstructor;
