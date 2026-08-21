export const cancellableDelay: <
  Args,
  TupleArgs extends Args extends unknown[] ? Args : [Args]
>(
  timeoutInSeconds: number,
  func: (...args: TupleArgs) => void,
  ...args: TupleArgs
) => () => void;
