export type InputModeKey = Enum.UserInputType | Enum.KeyCode | string;
export type InputModeTypeDefinition = (InputModeType | InputModeKey)[];

interface InputModeType {
  Name: string;
  IsValid(inputType: InputModeKey): boolean;
  GetKeys(): InputModeKey[];
}

interface InputModeTypeConstructor {
  readonly ClassName: 'InputModeType';
  new (
    name: string,
    typesAndInputModeTypes: InputModeTypeDefinition
  ): InputModeType;

  isInputModeType: (value: unknown) => value is InputModeType;
}

export const InputModeType: InputModeTypeConstructor;
