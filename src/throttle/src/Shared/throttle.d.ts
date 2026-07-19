import { ThrottleConfig } from './ThrottledFunction';

export const throttle: <
  Args,
  TupleArgs extends Args extends unknown[] ? Args : [Args]
>(
  timeoutInSeconds: number,
  func: (...args: TupleArgs) => void,
  throttleConfig?: ThrottleConfig
) => (...args: TupleArgs) => void;
