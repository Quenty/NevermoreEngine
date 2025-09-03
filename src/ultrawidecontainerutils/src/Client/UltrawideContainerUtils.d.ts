export namespace UltrawideContainerUtils {
  function createContainer(
    parent?: Instance
  ): LuaTuple<[Frame, UISizeConstraint]>;
  function scaleSizeConstraint(
    container: Frame,
    uiSizeConstraint: UISizeConstraint,
    scale: number
  ): void;
}
