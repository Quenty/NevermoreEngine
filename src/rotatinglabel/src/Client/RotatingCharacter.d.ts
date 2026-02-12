interface RotatingCharacter {
  Gui: GuiObject;
  TargetCharacter: string;
  Character: string;
  // cant type TransparencyList because of the metatable
  TransparencyList: unknown;
  readonly IsDoneAnimating: boolean;
  readonly NextCharacter: string;
  readonly Position: number;
  Transparency: number;
  readonly TransparencyMap: Map<
    GuiObject & {
      TextTransparency: number;
      TextStrokeTransparency: number;
    },
    number
  >;
  UpdatePositionRender(): void;
  UpdateRender(): void;
  CharToInt(char: string): number;
  Destroy(): void;
}

interface RotatingCharacterConstructor {
  readonly ClassName: 'RotatingCharacter';
  new (gui: GuiObject): RotatingCharacter;
}

export const RotatingCharacter: RotatingCharacterConstructor;
