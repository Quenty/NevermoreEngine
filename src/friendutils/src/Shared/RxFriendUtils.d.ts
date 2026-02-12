import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace RxFriendUtils {
  function observeFriendsInServerAsBrios(
    player?: Player
  ): Observable<Brio<Player>>;
}
