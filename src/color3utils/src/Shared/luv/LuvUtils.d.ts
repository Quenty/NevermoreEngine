import { LuvColor3 } from './LuvColor3Utils';

type Line = {
  slope: number;
  intercept: number;
};

export namespace LuvUtils {
  const m: [LuvColor3, LuvColor3, LuvColor3];
  const minv: [LuvColor3, LuvColor3, LuvColor3];
  const refY: 1.0;
  const refU: 0.19783000664283;
  const refV: 0.46831999493879;
  const kappa: 903.2962962;
  const epsilon: 0.0088564516;

  function get_bounds(l: number): Line[];
  function max_safe_chroma_for_l(l: number): number;
  function max_safe_chroma_for_lh(l: number, h: number): number;
  function dot_product(a: LuvColor3, b: LuvColor3): number;
  function from_linear(c: number): number;
  function to_linear(c: number): number;
  function xyz_to_rgb(luvColor3: LuvColor3): LuvColor3;
  function rgb_to_xyz(luvColor3: LuvColor3): LuvColor3;
  function y_to_l(y: number): number;
  function l_to_y(l: number): number;
  function xyz_to_luv(luvColor3: LuvColor3): LuvColor3;
  function luv_to_xyz(luvColor3: LuvColor3): LuvColor3;
  function luv_to_lch(luvColor3: LuvColor3): LuvColor3;
  function lch_to_luv(luvColor3: LuvColor3): LuvColor3;
  function hsluv_to_lch(luvColor3: LuvColor3): LuvColor3;
  function lch_to_hsluv(luvColor3: LuvColor3): LuvColor3;
  function hpluv_to_lch(luvColor3: LuvColor3): LuvColor3;
  function lch_to_hpluv(luvColor3: LuvColor3): LuvColor3;
  function rgb_to_hex(luvColor3: LuvColor3): string;
  function hex_to_rgb(hex: string): LuvColor3;
  function lch_to_rgb(luvColor3: LuvColor3): LuvColor3;
  function rgb_to_lch(luvColor3: LuvColor3): LuvColor3;
  function hsluv_to_rgb(luvColor3: LuvColor3): LuvColor3;
  function rgb_to_hsluv(luvColor3: LuvColor3): LuvColor3;
  function hpluv_to_rgb(luvColor3: LuvColor3): LuvColor3;
  function rgb_to_hpluv(luvColor3: LuvColor3): LuvColor3;
  function hsluv_to_hex(luvColor3: LuvColor3): string;
  function hpluv_to_hex(luvColor3: LuvColor3): string;
  function hex_to_hsluv(hex: string): LuvColor3;
  function hex_to_hpluv(hex: string): LuvColor3;
}
