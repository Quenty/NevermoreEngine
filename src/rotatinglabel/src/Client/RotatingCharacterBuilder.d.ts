import { RotatingCharacter } from './RotatingCharacter';

interface RotatingCharacterBuilder {
  WithTemplate(textLabelTemplate: TextLabel): this;
  Generate(parent: Instance): this;
  WithGui(gui: GuiObject): this;
  WithCharacter(char: string): this;
  Create(): RotatingCharacter;
}

interface RotatingCharacterBuilderConstructor {
  readonly ClassName: 'RotatingCharacterBuilder';
  new (): RotatingCharacterBuilder;
}

export const RotatingCharacterBuilder: RotatingCharacterBuilderConstructor;
