import { ServiceBag } from '@quenty/servicebag';
import { SettingDefinition } from './Setting/SettingDefinition';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';
import { PlayerSettingsBase } from './Player/PlayerSettingsBase';
import { CancelToken } from '@quenty/canceltoken';
import { Promise } from '@quenty/promise';

export interface SettingsDataService {
  readonly ServiceName: 'SettingsDataService';
  Init(serviceBag: ServiceBag): void;
  GetSettingDefinitions(): SettingDefinition<unknown>[];
  RegisterSettingDefinition(definition: SettingDefinition<unknown>): () => void;
  ObserveRegisteredDefinitionsBrio(): Observable<
    Brio<SettingDefinition<unknown>>
  >;
  ObservePlayerSettings(player: Player): Observable<PlayerSettingsBase>;
  ObservePlayerSettingsBrio(
    player: Player
  ): Observable<Brio<PlayerSettingsBase>>;
  PromisePlayerSettings(
    player: Player,
    cancelToken?: CancelToken
  ): Promise<PlayerSettingsBase>;
  GetPlayerSettings(player: Player): PlayerSettingsBase;
  Destroy(): void;
}
