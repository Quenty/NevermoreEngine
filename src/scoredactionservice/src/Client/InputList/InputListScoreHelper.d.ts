import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { ScoredActionPickerProvider } from '../Picker/ScoredActionPickerProvider';
import { ScoredAction } from '../ScoredAction';
import { InputKeyMapList } from '@quenty/inputkeymaputils';

interface InputListScoreHelper extends BaseObject {}

interface InputListScoreHelperConstructor {
  readonly ClassName: 'InputListScoreHelper';
  new (
    serviceBag: ServiceBag,
    provider: ScoredActionPickerProvider,
    scoredAction: ScoredAction,
    inputKeyMapList: InputKeyMapList
  ): InputListScoreHelper;
}

export const InputListScoreHelper: InputListScoreHelperConstructor;
