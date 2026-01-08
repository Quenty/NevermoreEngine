import { ServiceBag } from '@quenty/servicebag';

export interface InputKeyMapService {
  readonly ServiceName: 'InputKeyMapService';
  Init(serviceBag: ServiceBag): void;
}
