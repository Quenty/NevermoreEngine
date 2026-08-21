import { ServiceBag } from '@quenty/servicebag';
import { PlayerInputMode } from '../Shared/PlayerInputModeTypes';
import { CancelToken } from '@quenty/canceltoken';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';

export interface PlayerInputModeService {
  readonly ServiceName: 'PlayerInputModeService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetPlayerInputModeType(player: Player): PlayerInputMode | undefined;
  PromisePlayerInputMode(
    player: Player,
    cancelToken?: CancelToken
  ): Promise<PlayerInputMode>;
  ObservePlayerInputType(
    player: Player
  ): Observable<PlayerInputMode | undefined>;
}
