interface RotatingLabel {
  SetGui(gui: GuiObject): void;
  SetTemplate(template: TextLabel): void;
  Text: string;
  readonly TotalWidth: number;
  Width: number;
  Transparency: number;
  Damper: number;
  Speed: number;
  TextXAlignment: string;
  UpdateRender(): void;
  Destroy(): void;
}

interface RotatingLabelConstructor {
  readonly ClassName: 'RotatingLabel';
  new (): RotatingLabel;
}

export const RotatingLabel: RotatingLabelConstructor;
