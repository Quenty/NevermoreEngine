import { ServiceBag } from '@quenty/servicebag';
import { GameConfigPicker } from '../Shared/Config/Picker/GameConfigPicker';

export interface GameConfigServiceClient {
  readonly ServiceName: 'GameConfigServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetConfigPicker(): GameConfigPicker;
  Destroy(): void;
}
