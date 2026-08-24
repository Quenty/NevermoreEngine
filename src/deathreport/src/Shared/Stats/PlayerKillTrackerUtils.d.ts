import { Binder } from '@quenty/binder';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace PlayerKillTrackerUtils {
  function create(binder: Binder<unknown>, player: Player): void;
  function observeBrio<T>(
    binder: Binder<T>,
    player: Player
  ): Observable<Brio<T>>;
  function getPlayerKillTracker<T>(
    binder: Binder<T>,
    player: Player
  ): T | undefined;
}
