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

  CIRCLE_IMAGE_ID: 'rbxassetid://633244888';
  CIRCLE_SIZE: Vector2;
  SHADOW_IMAGE_ID: 'rbxassetid://707852973';
  SHADOW_SIZE: Vector2;
  PILL_SHADOW_IMAGE_ID: 'rbxassetid://1304004290';
  PILL_SHADOW_SIZE: Vector2;
  SHADOW_OFFSET_Y: UDim;
  SHADOW_TRANSPARENCY: 0.85;
}

export const PillBackingBuilder: PillBackingBuilderConstructor;
