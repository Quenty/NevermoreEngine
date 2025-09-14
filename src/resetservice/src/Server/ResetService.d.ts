import { Promise } from '@quenty/promise';

export interface ResetService {
  Init(): void;
  PushResetProvider(promiseReset: (player: Player) => Promise): () => void;
  PromiseResetCharacter(player: Player): Promise;
  Destroy(): void;
}
