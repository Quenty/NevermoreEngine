import { BaseObject } from '@quenty/baseobject';
import { InputType } from '@quenty/inputkeymaputils';
import { ScoredActionPicker } from './ScoredActionPicker';

interface ScoredActionPickerProvider extends BaseObject {
  FindPicker(inputType: InputType): ScoredActionPicker | undefined;
  GetOrCreatePicker(inputType: InputType): ScoredActionPicker;
  Update(): void;
}

interface ScoredActionPickerProviderConstructor {
  readonly ClassName: 'ScoredActionPickerProvider';
  new (): ScoredActionPickerProvider;
}

export const ScoredActionPickerProvider: ScoredActionPickerProviderConstructor;
