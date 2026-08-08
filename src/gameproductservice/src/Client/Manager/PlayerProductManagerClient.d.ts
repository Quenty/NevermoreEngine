import { ServiceBag } from '@quenty/servicebag';
import { PlayerProductManagerBase } from '../../Shared/Trackers/PlayerProductManagerBase';
import { Binder } from '@quenty/binder';

interface PlayerProductManagerClient extends PlayerProductManagerBase {}

interface PlayerProductManagerClientConstructor {
  readonly ClassName: 'PlayerProductManagerClient';
  new (obj: Player, serviceBag: ServiceBag): PlayerProductManagerClient;
}

export const PlayerProductManagerClient: Binder<PlayerProductManagerClient>;
