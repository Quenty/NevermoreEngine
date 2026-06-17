import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace RxCharacterUtils {
  function observeLastCharacterBrio(player: Player): Observable<Brio<Model>>;
  function observeCharacter(player: Player): Observable<Model | undefined>;
  function observeCharacterBrio(player: Player): Observable<Brio<Model>>;
  function observeIsOfLocalCharacter(instance: Instance): Observable<boolean>;
  function observeIsOfLocalCharacterBrio(
    instance: Instance
  ): Observable<Brio<boolean>>;
  function observeLocalPlayerCharacter(): Observable<Model | undefined>;
  function observeLastHumanoidBrio(player: Player): Observable<Brio<Humanoid>>;
  function observeLastAliveHumanoidBrio(
    player: Player
  ): Observable<Brio<Humanoid>>;
}
