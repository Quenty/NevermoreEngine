import { Signal } from '@quenty/signal';
import { InputModeKey, InputModeType } from '../Shared/InputModeType';

interface InputMode {
  Enabled: Signal;
  GetLastEnabledTime(): number;
  GetKeys(): InputModeKey[];
  IsValid(inputType: InputModeKey): boolean;
  Enable(): void;
  Evaluate(inputObject: InputObject): void;
  Destroy(): void;
}

interface InputModeConstructor {
  readonly ClassName: 'InputMode';
  new (inputModeType: InputModeType): InputMode;

  isInputMode: (value: unknown) => value is InputMode;
}

export const InputMode: InputModeConstructor;
