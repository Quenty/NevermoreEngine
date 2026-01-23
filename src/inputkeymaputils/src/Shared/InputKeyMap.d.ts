import { InputModeType } from '@quenty/inputmode';
import { InputType } from './Types/InputTypeUtils';
import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';

interface InputKeyMap extends BaseObject {
  GetInputModeType(): InputModeType;
  SetInputTypesList(inputTypes: InputType[]): void;
  SetDefaultInputTypesList(inputTypes: InputType[]): void;
  GetDefaultInputTypesList(): InputType[];
  RestoreDefault(): void;
  ObserveInputTypesList(): Observable<InputType[]>;
  GetInputTypesList(): InputType[];
}

interface InputKeyMapConstructor {
  readonly ClassName: 'InputKeyMap';
  new (inputModeType: InputModeType, inputTypes?: InputType[]): InputKeyMap;
}

export const InputKeyMap: InputKeyMapConstructor;
