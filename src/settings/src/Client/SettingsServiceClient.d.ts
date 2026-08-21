import { ServiceBag } from '@quenty/servicebag';
import { PlayerSettingsClient } from './Player/PlayerSettingsClient';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';
import { Promise } from '@quenty/promise';
import { CancelToken } from '@quenty/canceltoken';

export interface SettingsServiceClient {
  readonly ServiceName: 'SettingsServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetLocalPlayerSettings(): PlayerSettingsClient | undefined;
  ObserveLocalPlayerSettingsBrio(): Observable<Brio<PlayerSettingsClient>>;
  ObserveLocalPlayerSettings(): Observable<PlayerSettingsClient | undefined>;
  PromiseLocalPlayerSettings(
    cancelToken?: CancelToken
  ): Promise<PlayerSettingsClient>;
  ObservePlayerSettings(
    player: Player
  ): Observable<PlayerSettingsClient | undefined>;
  ObservePlayerSettingsBrio(
    player: Player
  ): Observable<Brio<PlayerSettingsClient>>;
  GetPlayerSettings(player: Player): PlayerSettingsClient | undefined;
  PromisePlayerSettings(
    player: Player,
    cancelToken?: CancelToken
  ): Promise<PlayerSettingsClient>;
  Destroy(): void;
}
