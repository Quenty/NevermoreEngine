import { InputModeType } from '@quenty/inputmode';
import { InputKeyMapList } from '../InputKeyMapList';

export type SlotId =
  | 'primary1'
  | 'primary2'
  | 'primary3'
  | 'primary4'
  | 'primary5'
  | 'inner1'
  | 'inner2'
  | 'jumpbutton'
  | 'touchpad1';

export interface SlottedTouchButton {
  type: 'SlottedTouchButton';
  slotId: SlotId;
}

export interface SlottedTouchButtonData {
  slotId: SlotId;
  inputModeType: InputModeType;
}

export namespace SlottedTouchButtonUtils {
  function createSlottedTouchButton(slotId: SlotId): SlottedTouchButton;
  function isSlottedTouchButton(value: unknown): value is SlottedTouchButton;
  function createTouchButtonData(
    slotId: SlotId,
    inputModeType: InputModeType
  ): SlottedTouchButtonData;
  function getSlottedTouchButtonData(
    inputKeyMapList: InputKeyMapList
  ): SlottedTouchButtonData[];
}
