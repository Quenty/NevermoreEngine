import { ServiceBag } from '@quenty/servicebag';
import { PlayerProductManagerBase } from '../../Shared/Trackers/PlayerProductManagerBase';
import { PlayerBinder } from '@quenty/playerbinder';

interface PlayerProductManager extends PlayerProductManagerBase {}

interface PlayerProductManagerConstructor {
  readonly ClassName: 'PlayerProductManager';
  new (player: Player, serviceBag: ServiceBag): PlayerProductManager;
}

export const PlayerProductManager: PlayerBinder<PlayerProductManager>;
