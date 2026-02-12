import { BaseObject } from '@quenty/baseobject';
import { InputKeyMapList } from '@quenty/inputkeymaputils';
import { ServiceBag } from '@quenty/servicebag';

interface InputKeyMapSetting extends BaseObject {}

interface InputKeyMapSettingConstructor {
  readonly ClassName: 'InputKeyMapSetting';
  new (
    serviceBag: ServiceBag,
    inputKeyMapList: InputKeyMapList
  ): InputKeyMapSetting;
}

export const InputKeyMapSetting: InputKeyMapSettingConstructor;
