import { Binder } from '@quenty/binder';
import { ServiceBag } from '@quenty/servicebag';
import { PlayerSettingsBase } from '../../Shared/Player/PlayerSettingsBase';

interface PlayerSettings extends PlayerSettingsBase {
  EnsureInitialized(
    settingName: string,
    defaultValue: NonNullable<unknown>
  ): void;
}

interface PlayerSettingsConstructor {
  readonly ClassName: 'PlayerSettings';
  new (folder: Folder, serviceBag: ServiceBag): PlayerSettings;
}

export const PlayerSettings: Binder<PlayerSettings>;
