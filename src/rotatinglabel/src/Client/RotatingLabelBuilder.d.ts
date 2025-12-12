import { RotatingLabel } from './RotatingLabel';

interface RotatingLabelBuilder {
  WithTemplate(template: TextLabel): this;
  WithGui(gui: GuiObject): this;
  Create(): RotatingLabel;
}

interface RotatingLabelBuilderConstructor {
  readonly ClassName: 'RotatingLabelBuilder';
  new (template?: TextLabel): RotatingLabelBuilder;
}

export const RotatingLabelBuilder: RotatingLabelBuilderConstructor;
