import { Brio } from '../../../brio';
import { Observable } from '../../../rx';

export namespace RxCollectionServiceUtils {
  function observeTaggedBrio(tagName: string): Observable<Brio<Instance>>;
  function observeTagged(tagName: string): Observable<Instance>;
}
