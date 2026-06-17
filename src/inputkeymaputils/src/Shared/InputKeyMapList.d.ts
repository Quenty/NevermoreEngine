import { BaseObject } from '@quenty/baseobject';
import { InputKeyMap } from './InputKeyMap';
import { InputModeKey, InputModeType } from '@quenty/inputmode';
import { InputType } from './Types/InputTypeUtils';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';
import { SlottedTouchButtonData } from './Types/SlottedTouchButtonUtils';

export interface InputKeyMapListOptions {
  bindingName: string;
  rebindable: boolean;
}

interface InputKeyMapList extends BaseObject {
  IsUserRebindable(): boolean;
  GetBindingName(): string;
  GetBindingTranslationKey(): string;
  Add(inputKeyMap: InputKeyMap): void;
  GetListName(): string;
  SetInputTypesList(
    inputModeType: InputModeType,
    inputTypes?: InputType[]
  ): void;
  SetDefaultInputTypesList(
    inputModeType: InputModeType,
    inputTypes?: InputType[]
  ): void;
  GetInputTypesList(inputModeType: InputModeType): InputType[];
  GetInputKeyMaps(): InputKeyMap[];
  GetDefaultInputTypesList(inputModeType: InputModeType): InputType[];
  ObservePairsBrio(): Observable<
    Brio<[inputModeType: InputModeType, inputKeyMap: InputKeyMap]>
  >;
  RestoreDefault(): void;
  RemoveInputModeType(inputModeType: InputModeType): void;
  ObserveInputKeyMapsBrio(): Observable<Brio<InputKeyMap>>;
  ObserveInputModesTypesBrio(): Observable<Brio<InputModeType>>;
  ObserveInputKeyMapForInputMode(
    inputModeType: InputModeType
  ): Observable<InputKeyMap | undefined>;
  ObserveIsTapInWorld(): Observable<boolean>;
  ObserveIsRobloxTouchButton(): Observable<boolean>;
  IsRobloxTouchButton(): boolean;
  IsTouchTapInWorld(): boolean;
  ObserveInputEnumsList(): Observable<InputType[]>;
  GetInputEnumsList(): InputType[];
  ObserveInputEnumsSet(): Observable<Map<InputType, true>>;
  ObserveSlottedTouchButtonDataBrio(): Observable<Brio<SlottedTouchButtonData>>;
  GetModifierChords(): {};
}

interface InputKeyMapListConstructor {
  readonly ClassName: 'InputKeyMapList';
  new (
    inputMapName: string,
    inputKeyMapList: InputKeyMap[],
    options: InputKeyMapListOptions
  ): InputKeyMapList;

  fromInputKeys: (
    inputKeys: InputModeKey[],
    options?: InputKeyMapListOptions
  ) => InputKeyMapList;
  isInputKeyMapList: (value: unknown) => value is InputKeyMapList;
}

export const InputKeyMapList: InputKeyMapListConstructor;
