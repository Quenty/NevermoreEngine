import { Observable, Predicate } from '../../../rx';

export namespace RxPlayerUtils {
  function observePlayersBrio(
    predicate?: Predicate<Player>
  ): Observable<Player>;
  function observeLocalPlayerBrio(
    predicate?: Predicate<Player>
  ): Observable<Player>;
  function observePlayers(predicate?: Predicate<Player>): Observable<Player>;
  function observeFirstAppearanceLoaded(player: Player): Observable;
}
