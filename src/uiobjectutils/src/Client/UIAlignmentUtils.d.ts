export namespace UIAlignmentUtils {
  function toNumber(
    alignment: Enum.HorizontalAlignment | Enum.VerticalAlignment
  ): 0 | 0.5 | 1;
  function verticalToHorizontalAlignment(
    verticalAlignment: Enum.VerticalAlignment
  ): Enum.HorizontalAlignment;
  function horizontalToVerticalAlignment(
    horizontalAlignment: Enum.HorizontalAlignment
  ): Enum.VerticalAlignment;
  function toBias(
    alignment: Enum.HorizontalAlignment | Enum.VerticalAlignment
  ): -1 | 0 | 1;
  function horizontalAlignmentToNumber(
    horizontalAlignment: Enum.HorizontalAlignment
  ): 0 | 0.5 | 1;
  function horizontalAlignmentToBias(
    horizontalAlignment: Enum.HorizontalAlignment
  ): -1 | 0 | 1;
  function verticalAlignmentToNumber(
    verticalAlignment: Enum.VerticalAlignment
  ): 0 | 0.5 | 1;
  function verticalAlignmentToBias(
    verticalAlignment: Enum.VerticalAlignment
  ): -1 | 0 | 1;
}
