import { CancelToken } from '@quenty/canceltoken';
import { Binder } from '../Binder';
import { Promise } from '@quenty/promise';

export const promiseBoundClass: <T>(
  binder: Binder<T>,
  inst: Instance,
  cancelToken?: CancelToken
) => Promise<T>;
