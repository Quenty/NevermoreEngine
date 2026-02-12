import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace RxTeleportUtils {
  function observeTeleportBrio(player: Player): Observable<Brio<number>>;
}
