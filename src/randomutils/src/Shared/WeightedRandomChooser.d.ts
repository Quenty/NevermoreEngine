interface WeightedRandomChooser<T> {
  SetWeight(option: T, weight: number | undefined): void;
  Remove(option: T): void;
  GetWeight(option: T): number | undefined;
  GetProbability(option: T): number | undefined;
  Choose(random?: Random): T;
}

interface WeightedRandomChooserConstructor {
  readonly ClassName: 'WeightedRandomChooser';
  new (): WeightedRandomChooser<unknown>;
  new <T>(): WeightedRandomChooser<T>;
}

export const WeightedRandomChooser: WeightedRandomChooserConstructor;
