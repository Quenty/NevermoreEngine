import { BaseObject } from '@quenty/baseobject';
import { ScoredAction } from '../ScoredAction';

interface TouchButtonScoredActionPicker extends BaseObject {
  Update(): void;
  AddAction(action: ScoredAction): void;
  RemoveAction(action: ScoredAction): void;
  HasActions(): boolean;
}

interface TouchButtonScoredActionPickerConstructor {
  readonly ClassName: 'TouchButtonScoredActionPicker';
  new (): TouchButtonScoredActionPicker;
}

export const TouchButtonScoredActionPicker: TouchButtonScoredActionPickerConstructor;
