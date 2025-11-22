export namespace UIPaddingUtils {
  function fromUDim(udim: UDim): UIPadding;
  function getTotalPadding(uiPadding: UIPadding): UDim2;
  function getTotalAbsolutePadding(uiPadding: UIPadding): Vector2;
  function getHorizontalPadding(uiPadding: UIPadding): UDim;
}
