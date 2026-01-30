import { BaseObject } from '@quenty/baseobject';
import { ScoredAction } from '../ScoredAction';

interface ScoredActionPicker extends BaseObject {
  Update(): void;
  AddAction(action: ScoredAction): void;
  RemoveAction(action: ScoredAction): void;
  HasActions(): boolean;
}

interface ScoredActionPickerConstructor {
  readonly ClassName: 'ScoredActionPicker';
  new (): ScoredActionPicker;
}

export const ScoredActionPicker: ScoredActionPickerConstructor;
