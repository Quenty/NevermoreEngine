import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

interface ScoredAction extends BaseObject {
  PreferredChanged: Signal<boolean>;
  Removing: Signal;
  IsPreferred(): boolean;
  ObservePreferred(): Observable<boolean>;
  SetScore(score: number): void;
  GetScore(): number;
  PushPreferred(): () => void;
}

interface ScoredActionConstructor {
  readonly ClassName: 'ScoredAction';
  new (): ScoredAction;
}

export const ScoredAction: ScoredActionConstructor;
