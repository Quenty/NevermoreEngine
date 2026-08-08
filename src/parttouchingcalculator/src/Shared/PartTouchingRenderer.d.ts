interface PartTouchingRenderer {
  RenderTouchingProps(touchingPartList: BasePart[]): void;
}

interface PartTouchingRendererConstructor {
  readonly ClassName: 'PartTouchingRenderer';
  new (): PartTouchingRenderer;
}

export const PartTouchingRenderer: PartTouchingRendererConstructor;
