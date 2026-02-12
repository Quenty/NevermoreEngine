import { ServiceBag } from '@quenty/servicebag';
import { InputKeyMapList } from '../Shared/InputKeyMapList';

export interface InputKeyMapServiceClient {
  readonly ServiceName: 'InputKeyMapServiceClient';
  Init(serviceBag: ServiceBag): void;
  FindInputKeyMapList(
    providerName: string,
    listName: string
  ): InputKeyMapList | undefined;
  Destroy(): void;
}
