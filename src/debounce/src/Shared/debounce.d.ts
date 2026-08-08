export const debounce: <T extends unknown[]>(
  timeoutInSeconds: number,
  func: (...args: T) => unknown
) => (...args: T) => void;
