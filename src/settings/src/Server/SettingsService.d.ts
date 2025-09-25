import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';
import { PlayerSettings } from './Player/PlayerSettings';
import { Promise } from '@quenty/promise';
import { CancelToken } from '@quenty/canceltoken';

export interface SettingsService {
  readonly ServiceName: 'SettingsService';
  Init(serviceBag: ServiceBag): void;
  ObservePlayerSettingsBrio(player: Player): Observable<Brio<PlayerSettings>>;
  ObservePlayerSettings(player: Player): Observable<PlayerSettings>;
  GetPlayerSettings(player: Player): PlayerSettings;
  PromisePlayerSettings(
    player: Player,
    cancelToken?: CancelToken
  ): Promise<PlayerSettings>;
  Destroy(): void;
}
