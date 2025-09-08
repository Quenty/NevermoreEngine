interface ModelAppearance {
  DisableInteractions(): void;
  SetCanCollide(canCollide: boolean): void;
  ResetCanCollide(): void;
  SetTransparency(transparency: number): void;
  ResetTransparency(): void;
  SetColor(color: Color3): void;
  ResetColor(): void;
  ResetMaterial(): void;
  SetMaterial(material: Enum.Material): void;
}

interface ModelAppearanceConstructor {
  readonly ClassName: 'ModelAppearance';
  new (model: Instance): ModelAppearance;
}

export const ModelAppearance: ModelAppearanceConstructor;
