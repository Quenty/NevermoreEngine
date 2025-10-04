import { Observable } from '@quenty/rx';
import { PlayerInputMode } from './PlayerInputModeTypes';
import { CancelToken } from '@quenty/canceltoken';
import { Promise } from '@quenty/promise';

export namespace PlayerInputModeUtils {
  function getPlayerInputModeType(player: Player): PlayerInputMode | undefined;
  function observePlayerInputModeType(
    player: Player
  ): Observable<PlayerInputMode | undefined>;
  function promisePlayerInputMode(
    player: Player,
    cancelToken?: CancelToken
  ): Promise<string>;
  function isInputModeType(value: unknown): value is PlayerInputMode;
  function setPlayerInputModeType(
    player: Player,
    playerInputModeType: PlayerInputMode
  ): void;
}
