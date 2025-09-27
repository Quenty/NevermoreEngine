import { Promise } from '@quenty/promise';

export interface PromiseRemoteFunctionMixin {
  PromiseRemoteFunction(): Promise<RemoteEvent>;
}

export const PromiseRemoteFunctionMixin: {
  Add(
    classObj: { new (...args: unknown[]): unknown },
    remoteFunctionName: string
  ): void;
};
