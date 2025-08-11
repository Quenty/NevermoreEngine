import { Observable, Predicate } from '../../../rx';

export namespace RxPlayerUtils {
  function observePlayersBrio(predicate?: Predicate): Observable<[Player]>;
  function observeLocalPlayerBrio(predicate?: Predicate): Observable<Player>;
  function observePlayers(predicate?: Predicate): Observable<[Player]>;
  function observeFirstAppearanceLoaded(player: Player): Observable;
}
