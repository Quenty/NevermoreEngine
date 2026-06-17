type LuvColor3 = [l: number, u: number, v: number];

export namespace LuvColor3Utils {
  function lerp(a: Color3, b: Color3, t: number): Color3;
  function desaturate(color3: Color3, proportion: number): Color3;
  function darken(color3: Color3, proportion: number): Color3;
  function fromColor3(color3: Color3): LuvColor3;
  function toColor3(luv: LuvColor3): Color3;
}
