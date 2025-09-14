interface GuiTriangle {
  SetParent(parent?: Instance): void;
  Show(): void;
  Set(a: Vector2, b: Vector2, c: Vector2): GuiTriangle;
  Hide(): void;
  SetA(a: Vector2): GuiTriangle;
  SetB(b: Vector2): GuiTriangle;
  SetC(c: Vector2): GuiTriangle;
  UpdateRender(): void;
  Destroy(): void;
}

interface GuiTriangleConstructor {
  readonly ClassName: 'GuiTriangle';
  new (parent?: Instance): GuiTriangle;

  ExtraPixels: 2;
}

export const GuiTriangle: GuiTriangleConstructor;
