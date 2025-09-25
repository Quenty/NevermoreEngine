import { BaseObject } from '@quenty/baseobject';
import { RobloxDataStore } from './Utility/DataStorePromises';
import { Promise } from '@quenty/promise';
import { DataStore } from './DataStore';

interface PlayerDataStoreManager extends BaseObject {
  DisableSaveOnCloseStudio(): void;
  AddRemovingCallback(callback: () => Promise<unknown> | void): void;
  RemovePlayerDataStore(player: Player): void;
  GetDataStore(player: Player): DataStore<unknown> | undefined;
  PromiseAllSaves(): Promise;
}

interface PlayerDataStoreManagerConstructor {
  readonly ClassName: 'PlayerDataStoreManager';
  new (
    robloxDataStore: RobloxDataStore,
    keyGenerator: (player: Player) => string,
    skipBindingToClose?: boolean
  ): PlayerDataStoreManager;
}

export const PlayerDataStoreManager: PlayerDataStoreManagerConstructor;
