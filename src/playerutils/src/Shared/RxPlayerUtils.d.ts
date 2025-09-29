import { Observable, Predicate } from '@quenty/rx';
import { Brio } from '@quenty/brio';

export namespace RxPlayerUtils {
  function observePlayersBrio(
    predicate?: Predicate<Player>
  ): Observable<Brio<Player>>;
  function observeLocalPlayerBrio(
    predicate?: Predicate<Player>
  ): Observable<Brio<Player>>;
  function observePlayers(predicate?: Predicate<Player>): Observable<Player>;
  function observeFirstAppearanceLoaded(player: Player): Observable;
}
