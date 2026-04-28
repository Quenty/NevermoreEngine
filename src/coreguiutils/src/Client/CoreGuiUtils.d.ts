export namespace CoreGuiUtils {
  function promiseRetrySetCore(
    tries: number,
    initialWaitTime: number,
    ...args: Parameters<typeof tryToSetCore>
  ): void;
  function tryToSetCore<T extends keyof SettableCores>(
    parameter: T,
    option: SettableCores[T]
  ): boolean;
}
