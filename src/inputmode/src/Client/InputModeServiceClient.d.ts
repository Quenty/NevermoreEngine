import { ServiceBag } from '@quenty/servicebag';
import { InputModeType } from '../Shared/InputModeType';
import { InputMode } from './InputMode';

export interface InputModeServiceClient {
  readonly ServiceName: 'InputModeServiceClient';
  Init(serviceBag: ServiceBag): void;
  GetInputMode(inputModeType: InputModeType): InputMode;
  Destroy(): void;
}
