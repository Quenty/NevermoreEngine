import { ServiceBag } from '@quenty/servicebag';
import { InputKeyMapList } from './InputKeyMapList';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';

interface InputKeyMapListProvider {
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetProviderName(): string;
  GetInputKeyMapList(keyMapListName: string): InputKeyMapList;
  FindInputKeyMapList(keyMapListName: string): InputKeyMapList | undefined;
  Add(inputKeyMapList: InputKeyMapList): void;
  ObserveInputKeyMapListsBrio(): Observable<Brio<InputKeyMapList>>;
  Destroy(): void;
}

interface InputKeyMapListProviderConstructor {
  readonly ClassName: 'InputKeyMapListProvider';
  readonly ServiceName: 'InputKeyMapListProvider';
  new (
    providerName: string,
    createDefaults: (
      this: InputKeyMapListProvider,
      serviceBag: ServiceBag
    ) => void
  ): InputKeyMapListProvider;
}

export const InputKeyMapListProvider: InputKeyMapListProviderConstructor;
