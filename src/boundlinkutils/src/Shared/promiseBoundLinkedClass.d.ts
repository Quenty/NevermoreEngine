import { Binder } from '@quenty/binder';
import { Promise } from '@quenty/promise';

export const promiseBoundLinkedClass: <T>(
  binder: Binder<T>,
  objValue: ObjectValue
) => Promise<T>;
