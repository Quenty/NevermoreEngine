import { BaseObject } from '@quenty/baseobject';
import { InputKeyMapList } from '@quenty/inputkeymaputils';
import { ServiceBag } from '@quenty/servicebag';

interface InputKeyMapSettingClient extends BaseObject {}

interface InputKeyMapSettingClientConstructor {
  readonly ClassName: 'InputKeyMapSettingClient';
  new (
    serviceBag: ServiceBag,
    inputKeyMapList: InputKeyMapList
  ): InputKeyMapSettingClient;
}

export const InputKeyMapSettingClient: InputKeyMapSettingClientConstructor;
