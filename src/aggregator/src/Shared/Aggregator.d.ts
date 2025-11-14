import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';

interface Aggregator<T> extends BaseObject {
  SetMaxBatchSize(maxBatchSize: number): void;
  Promise(id: number): Promise<T>;
  Observe(id: number): Observable<T>;
}

interface AggregatorConstructor {
  readonly ClassName: 'Aggregator';
  new <T>(
    debugName: string,
    promiseBulkQuery: (idList: number[]) => Promise<T>
  ): Aggregator<T>;
}

export const Aggregator: AggregatorConstructor;
