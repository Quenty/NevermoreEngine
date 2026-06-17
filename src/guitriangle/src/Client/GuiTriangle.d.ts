interface GuiTriangle {
  SetParent(parent?: Instance): void;
  Show(): void;
  Set(a: Vector2, b: Vector2, c: Vector2): this;
  Hide(): void;
  SetA(a: Vector2): this;
  SetB(b: Vector2): this;
  SetC(c: Vector2): this;
  UpdateRender(): void;
  Destroy(): void;
}

interface GuiTriangleConstructor {
  readonly ClassName: 'GuiTriangle';
  new (parent?: Instance): GuiTriangle;

  ExtraPixels: 2;
}

export const GuiTriangle: GuiTriangleConstructor;
