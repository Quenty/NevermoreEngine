import { Brio } from '@quenty/brio';
import { Observable, Predicate } from '@quenty/rx';

export namespace RxSelectionUtils {
  function observeFirstSelectionWhichIsA(
    className: keyof Instances
  ): Observable<Instance | undefined>;
  function observeFirstSelectionWhichIsABrio(
    className: keyof Instances
  ): Observable<Instance | undefined>;
  function observeFirstAdornee(): Observable<Instance | undefined>;
  function observeAdorneesBrio(): Observable<Brio<Instance>>;
  function observeFirstSelection(
    where: Predicate<Instance>
  ): Observable<Instance | undefined>;
  function observeFirstSelectionBrio(
    where: Predicate<Instance>
  ): Observable<Brio<Instance>>;
  function observeSelectionList(): Observable<Instance[]>;
  function observeSelectionItemsBrio(): Observable<Brio<Instance>>;
}
