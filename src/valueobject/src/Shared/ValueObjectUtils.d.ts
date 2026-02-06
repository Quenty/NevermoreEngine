import { Brio } from '@quenty/brio';
import { Maid } from '@quenty/maid';
import { Observable } from '@quenty/rx';
import { ValueObject } from './ValueObject';
import { Signal } from '@quenty/signal';

interface ValueChangedObjectLike<T> {
  Value: T;
  Changed: Signal | Signal<unknown>;
}

export namespace ValueObjectUtils {
  function syncValue<T>(
    from: ValueChangedObjectLike<T>,
    to: ValueChangedObjectLike<T>
  ): Maid;
  function observeValue<T>(valueObject: ValueObject<T>): Observable<T>;
  function observeValueBrio<T>(
    valueObject: ValueObject<T>
  ): Observable<Brio<T>>;
}
