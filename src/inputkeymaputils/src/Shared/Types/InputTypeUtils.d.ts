import { SlottedTouchButton } from './SlottedTouchButtonUtils';

export type InputType =
  | Enum.UserInputType
  | Enum.KeyCode
  | SlottedTouchButton
  | 'TouchButton'
  | 'Tap'
  | 'Drag';

export namespace InputTypeUtils {
  function isKnownInputType(value: unknown): value is InputType;
  function isTapInWorld(value: unknown): value is 'Tap';
  function isDrag(value: unknown): value is 'Drag';
  function isRobloxTouchButton(value: unknown): value is 'TouchButton';
  function createTapInWorld(): 'Tap';
  function createRobloxTouchButton(): 'TouchButton';
  function getUniqueKeyForInputType(inputType: InputType): InputType | string;
  function areInputTypesListsEquivalent(
    a: InputType[],
    b: InputType[]
  ): boolean;
}
