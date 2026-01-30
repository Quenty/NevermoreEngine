import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

export namespace RxTeamUtils {
  function observePlayerTeam(player: Player): Observable<Team | undefined>;
  function observePlayerTeamColor(
    player: Player
  ): Observable<BrickColor | undefined>;
  function observePayersForTeamBrio(team: Team): Observable<Brio<Player>>;
  function observeEnemyTeamColorPlayersBrio(
    teamColor: BrickColor
  ): Observable<Brio<Player>>;
  function observePlayersForTeamColorBrio(
    teamColor: BrickColor
  ): Observable<Brio<Player>>;
  function observeTeamsForColorBrio(
    teamColor: BrickColor
  ): Observable<Brio<Team>>;
  function observeTeamsBrio(): Observable<Brio<Team>>;
}
