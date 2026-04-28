import { BaseObject } from '../../../baseobject';
import { Observable } from '../../../rx';
import { Signal } from '@quenty/signal';

interface Counter extends BaseObject {
  Changed: Signal<number>;
  GetValue(): number;
  Add(amount: number | Observable<number>): () => void;
}

interface CounterConstructor {
  readonly ClassName: 'Counter';
  new (): Counter;
}

export const Counter: CounterConstructor;
