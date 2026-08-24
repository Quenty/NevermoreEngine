export namespace NumberSequenceUtils {
  function getValueGenerator(
    numberSequence: NumberSequence
  ): (time: number) => number;
  function forEachValue(
    sequence: NumberSequence,
    callback: (value: number) => number
  ): NumberSequence;
  function scale(sequence: NumberSequence, scale: number): NumberSequence;
  function scaleTransparency(
    sequence: NumberSequence,
    scale: number
  ): NumberSequence;
  function stripe(
    stripes: number,
    backgroundTransparency: number,
    stripeTransparency: number,
    percentStripeThickness: number,
    percentOffset: number
  ): NumberSequence;
}
