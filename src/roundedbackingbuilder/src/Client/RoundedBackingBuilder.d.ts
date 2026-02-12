interface RoundedBackingBuilder {
  Create(gui: GuiObject): ImageLabel;
  CreateBacking(gui: GuiObject): ImageLabel;
  CreateTopBacking(gui: GuiObject): ImageLabel;
  CreateLeftBacking(gui: GuiObject): ImageLabel;
  CreateRightBacking(gui: GuiObject): ImageLabel;
  CreateBottomBacking(gui: GuiObject): ImageLabel;
  CreateTopShadow(backing: GuiObject): ImageLabel;
  CreateShadow(backing: GuiObject): ImageLabel;
}

interface RoundedBackingBuilderConstructor {
  readonly ClassName: 'RoundedBackingBuilder';
  new (options?: { sibling: boolean }): RoundedBackingBuilder;
}

export const RoundedBackingBuilder: RoundedBackingBuilderConstructor;
