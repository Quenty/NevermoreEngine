import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';
import { PlayerInputMode } from '../Shared/PlayerInputModeTypes';

export interface PlayerInputModeServiceClient {
  readonly ServiceName: 'PlayerInputModeServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  ObservePlayerInputType(
    player: Player
  ): Observable<PlayerInputMode | undefined>;
  GetPlayerInputModeType(player: Player): PlayerInputMode | undefined;
  Destroy(): void;
}
