import { InputMode } from './InputMode';

interface InputModeProcessor {
  AddInputMode(inputMode: InputMode): void;
  GetStates(): InputMode[];
  Evaluate(inputObject: InputObject): void;
}

interface InputModeProcessorConstructor {
  readonly ClassName: 'InputModeProcessor';
  new (inputModes?: InputMode[]): InputModeProcessor;
}

export const InputModeProcessor: InputModeProcessorConstructor;
