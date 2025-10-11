import { Observable } from '@quenty/rx';
import { BodyColorsData } from './BodyColorsDataConstants';

export namespace RxBodyColorsDataUtils {
  function observeFromAttribute(instance: Instance): Observable<BodyColorsData>;
}
