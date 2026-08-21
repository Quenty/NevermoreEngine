import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { SettingDefinition } from '../Setting/SettingDefinition';
import { Observable } from '@quenty/rx';

interface PlayerSettingsBase extends BaseObject {
  GetPlayer(): Player | undefined;
  GetFolder(): Folder;
  GetSettingProperty(
    settingName: string,
    defaultValue: unknown
  ): SettingDefinition<unknown>;
  GetValue(settingName: string, defaultValue: NonNullable<unknown>): unknown;
  SetValue(setingName: string, value: NonNullable<unknown>): void;
  ObserveValue(
    settingName: string,
    defaultValue: NonNullable<unknown>
  ): Observable<unknown>;
  RestoreDefault(settingName: string, defaultValue: NonNullable<unknown>): void;
}

interface PlayerSettingsBaseConstructor {
  readonly ClassName: 'PlayerSettingsBase';
  new (folder: Folder, serviceBag: ServiceBag): PlayerSettingsBase;
}

export const PlayerSettingsBase: PlayerSettingsBaseConstructor;
