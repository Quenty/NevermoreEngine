import { Binder } from '@quenty/binder';
import { BinderGroup } from '@quenty/binder/src/Shared/BinderGroup';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx/src/Shared/Observable';

export namespace RxBinderGroupUtils {
  function observeBinders(
    binderGroup: BinderGroup
  ): Observable<Binder<unknown>>;
  function observeAllClassesBrio(
    binderGroup: BinderGroup
  ): Observable<Brio<unknown>>;
}
