import { ServiceBag } from '@quenty/servicebag';
import { InputKeyMapList } from '../Shared/InputKeyMapList';
import { InputModeType, InputModeTypeSelector } from '@quenty/inputmode';
import { Observable } from '@quenty/rx';
import { InputType } from '../Shared/Types/InputTypeUtils';

export namespace InputKeyMapListUtils {
  function getNewInputModeTypeSelector(
    inputKeyMapList: InputKeyMapList,
    serviceBag: ServiceBag
  ): InputModeTypeSelector;
  function observeActiveInputKeyMap(
    inputKeyMapList: InputKeyMapList,
    serviceBag: ServiceBag
  ): Observable<InputKeyMapList | undefined>;
  function observeActiveInputTypesList(
    inputKeyMapList: InputKeyMapList,
    serviceBag: ServiceBag
  ): Observable<InputType[] | undefined>;
  function observeActiveInputModeType(
    inputKeyMapList: InputKeyMapList,
    serviceBag: ServiceBag
  ): Observable<InputModeType | undefined>;
}
