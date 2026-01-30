import { Promise } from '@quenty/promise';

export interface PromiseRemoteEventMixin {
  PromiseRemoteEvent(): Promise<RemoteEvent>;
}

export const PromiseRemoteEventMixin: {
  Add(
    classObj: { new (...args: unknown[]): unknown },
    remoteEventName: string
  ): void;
};
