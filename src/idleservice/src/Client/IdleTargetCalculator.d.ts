import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

interface IdleTargetCalculator extends BaseObject {
  Changed: Signal<boolean>;
  GetShouldDisableContextUI(): boolean;
  ObserveShouldDisableContextUI(): Observable<boolean>;
  SetTarget(targetPosition: Vector3): void;
}

interface IdleTargetCalculatorConstructor {
  readonly ClassName: 'IdleTargetCalculator';
  new (): IdleTargetCalculator;
}

export const IdleTargetCalculator: IdleTargetCalculatorConstructor;
