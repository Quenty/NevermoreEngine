export interface PillBackingBuilderOptions {
  ZIndex?: number;
  ShadowZIndex?: number;
  BackgroundColor3?: Color3;
}

interface PillBackingBuilder {
  CreateSingle(gui: GuiObject, options?: PillBackingBuilderOptions): ImageLabel;
  CreateSingleShadow(
    gui: GuiObject,
    options?: PillBackingBuilderOptions
  ): ImageLabel;
  CreateShadow(
    gui: GuiObject,
    options?: PillBackingBuilderOptions
  ): ImageLabel & {
    UISizeConstraint: UISizeConstraint;
    LeftShadow: ImageLabel;
    RightShadow: ImageLabel;
  };
  CreateCircle(gui: GuiObject, options?: PillBackingBuilderOptions): ImageLabel;
  CreateCircleShadow(
    gui: GuiObject,
    options?: PillBackingBuilderOptions
  ): ImageLabel;
  CreateLeft(gui: GuiObject, options?: PillBackingBuilderOptions): ImageLabel;
  CreateRight(gui: GuiObject, options?: PillBackingBuilderOptions): ImageLabel;
  CreateTop(gui: GuiObject, options?: PillBackingBuilderOptions): ImageLabel;
  CreateBottom(gui: GuiObject, options?: PillBackingBuilderOptions): ImageLabel;
}

interface PillBackingBuilderConstructor {
  readonly ClassName: 'PillBackingBuilder';
  new (options?: PillBackingBuilderOptions): PillBackingBuilder;
}

export const PillBackingBuilder: PillBackingBuilderConstructor;
