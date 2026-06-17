export namespace Color3Utils {
  function getRelativeLuminance(color: Color3): number;
  function textShouldBeBlack(color: Color3): boolean;
  function scaleValue(color: Color3, percent: number): Color3;
  function setValue(color: Color3, value: number): Color3;
  function setHue(color: Color3, hue: number): Color3;
  function scaleSaturation(color: Color3, percent: number): Color3;
  function setSaturation(color: Color3, saturation: number): Color3;
  function areEqual(a: Color3, b: Color3, epsilon?: number): boolean;
  function toHexInteger(color: Color3): number;
  function toHexString(color: Color3): string;
  function toWebHexString(color: Color3): string;
}
