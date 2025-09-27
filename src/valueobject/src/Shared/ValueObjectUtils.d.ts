import { Brio } from '../../../brio';
import { Maid } from '@quenty/maid';
import { Observable } from '../../../rx';
import { ValueObject } from './ValueObject';

export namespace ValueObjectUtils {
  function syncValue<T>(from: ValueObject<T>, to: ValueObject<T>): Maid;
  function observeValue<T>(valueObject: ValueObject<T>): Observable<T>;
  function observeValueBrio<T>(
    valueObject: ValueObject<T>
  ): Observable<Brio<T>>;
}
