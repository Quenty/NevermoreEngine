import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';

interface RateAggregator<A extends unknown[], R> extends BaseObject {
  SetMaxRequestsPerSecond(maxRequestsPerSecond: number): void;
  Promise(...args: A): Promise<R>;
}

interface RateAggregatorConstructor {
  readonly ClassName: 'RateAggregator';
  new <A extends unknown[], R>(
    promiseQuery: (...args: A) => Promise<R>
  ): RateAggregator<A, R>;
}

export const RateAggregator: RateAggregatorConstructor;
