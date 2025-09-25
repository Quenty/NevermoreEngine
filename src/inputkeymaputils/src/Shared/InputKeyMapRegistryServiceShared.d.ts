import { ServiceBag } from '@quenty/servicebag';
import { InputKeyMapListProvider } from './InputKeyMapListProvider';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';
import { InputKeyMapList } from './InputKeyMapList';

export interface InputKeyMapRegistryServiceShared {
  readonly ServiceName: 'InputKeyMapRegistryServiceShared';
  Init(serviceBag: ServiceBag): void;
  RegisterProvider(provider: InputKeyMapListProvider): void;
  ObserveProvidersBrio(): Observable<Brio<InputKeyMapListProvider>>;
  ObserveInputKeyMapListsBrio(): Observable<Brio<InputKeyMapList>>;
  GetProvider(providerName: string): InputKeyMapListProvider | undefined;
  ObserveInputKeyMapList(
    providerName: string | Observable<string>,
    inputKeyMapListName: string | Observable<string>
  ): Observable<InputKeyMapList | undefined>;
  FindInputKeyMapList(
    providerName: string,
    inputKeyMapListName: string
  ): InputKeyMapList | undefined;
  Destroy(): void;
}
