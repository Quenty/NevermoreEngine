import { Binder } from '@quenty/binder';
import { CooldownBase } from './Binders/CooldownBase';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';

export namespace RxCooldownUtils {
  function observeCooldownBrio<T extends CooldownBase>(
    binder: Binder<T>,
    parent: Instance
  ): Observable<Brio<T>>;
}
