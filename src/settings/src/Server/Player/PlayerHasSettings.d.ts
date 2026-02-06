import { BaseObject } from '@quenty/baseobject';
import { PlayerBinder } from '@quenty/playerbinder';
import { ServiceBag } from '@quenty/servicebag';

interface PlayerHasSettings extends BaseObject {}

interface PlayerHasSettingsConstructor {
  readonly ClassName: 'PlayerHasSettings';
  new (player: Player, serviceBag: ServiceBag): PlayerHasSettings;
}

export const PlayerHasSettings: PlayerBinder<PlayerHasSettings>;
