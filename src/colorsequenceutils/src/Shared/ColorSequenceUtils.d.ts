export namespace ColorSequenceUtils {
  function getColor(colorSequence: ColorSequence, t: number): Color3;
  function stripe(
    stripes: number,
    backgroundColor3: Color3,
    stripeColor3: Color3,
    percentStripeThickness?: number,
    percentOffset?: number
  ): ColorSequence;
}
