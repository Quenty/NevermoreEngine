import { InputKeyMapList, InputType } from '@quenty/inputkeymaputils';
import { InputModeType } from '@quenty/inputmode';

export type EncodedInputTypeList = string & {
  __brand: 'EncodedInputTypeList';
};

export namespace InputKeyMapSettingUtils {
  function getSettingName(
    inputKeyMapList: InputKeyMapList,
    inputModeType: InputModeType
  ): string;
  function encodeInputTypeList(list: InputType[]): EncodedInputTypeList;
  function decodeInputTypeList(encoded: EncodedInputTypeList): InputType[];
}
