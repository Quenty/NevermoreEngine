import { Promise } from '../Promise';

interface PendingPromiseTracker {
  Add<T>(promise: Promise<T>): Promise<T>;
  GetAll(): Promise<unknown>[];
}

interface PendingPromiseTrackerConstructor {
  readonly ClassName: 'PendingPromiseTracker';
  new (): PendingPromiseTracker;
}

export const PendingPromiseTracker: PendingPromiseTrackerConstructor;
