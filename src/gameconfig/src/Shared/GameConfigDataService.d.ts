import { ServiceBag } from '@quenty/servicebag';
import { GameConfigPicker } from './Config/Picker/GameConfigPicker';

export interface GameConfigDataService {
  readonly ServiceName: 'GameConfigDataService';
  Init(serviceBag: ServiceBag): void;
  SetConfigPicker(configPicker: GameConfigPicker): void;
  GetConfigPicker(): GameConfigPicker;
}
