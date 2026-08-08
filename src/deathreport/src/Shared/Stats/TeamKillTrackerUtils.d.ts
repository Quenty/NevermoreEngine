import { Binder } from '@quenty/binder';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace TeamKillTrackerUtils {
  function create(binder: Binder<unknown>): void;
  function observeBrio<T>(binder: Binder<T>, team: Team): Observable<Brio<T>>;
  function getPlayerKillTracker<T>(
    binder: Binder<T>,
    team: Team
  ): T | undefined;
}
