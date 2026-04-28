import { Promise } from '@quenty/promise';

export namespace RemoteFunctionUtils {
  function promiseInvokeServer(
    remoteFunction: RemoteFunction,
    ...args: unknown[]
  ): Promise<unknown>;
  function promiseInvokeClient(
    remoteFunction: RemoteFunction,
    player: Player,
    ...args: unknown[]
  ): Promise<unknown>;
  function promiseInvokeBindableFunction(
    bindableFunction: BindableFunction,
    ...args: unknown[]
  ): Promise<unknown>;
  function fromPromiseYieldResult<T extends unknown[]>(
    ok: boolean,
    ...args: T
  ): T | Promise<T>;
}
