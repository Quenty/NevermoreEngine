import { ServiceBag } from '@quenty/servicebag';
import { PlayerSettingsBase } from '../../Shared/Player/PlayerSettingsBase';
import { Observable } from '@quenty/rx';
import { Binder } from '@quenty/binder';

interface PlayerSettingsClient extends PlayerSettingsBase {
  GetValue<T>(settingName: string, defaultValue: NonNullable<T>): T;
  ObserveValue<T>(
    settingName: string,
    defaultValue: NonNullable<T>
  ): Observable<T>;
  SetValue(settingName: string, value: unknown): void;
}

interface PlayerSettingsClientConstructor {
  readonly ClassName: 'PlayerSettingsClient';
  new (folder: Folder, serviceBag: ServiceBag): PlayerSettingsClient;
}

export const PlayerSettingsClient: Binder<PlayerSettingsClient>;
