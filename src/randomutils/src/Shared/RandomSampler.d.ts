interface RandomSampler<T> {
  SetSamples(samples: T[]): void;
  Sample(): T;
  Refill(): void;
}

interface RandomSamplerConstructor {
  readonly ClassName: 'RandomSampler';
  new <T>(samples: T[]): RandomSampler<T>;
}

export const RandomSampler: RandomSamplerConstructor;
