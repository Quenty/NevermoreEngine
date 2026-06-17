import { Promise } from '../Promise';

export const promiseChild: (
  parent: Instance,
  name: string,
  timeOut?: number
) => Promise<Instance>;
