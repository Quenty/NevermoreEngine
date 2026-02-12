import { Observable, Subscription } from '@quenty/rx';

type ToTuple<T> = T extends unknown[] ? T : [T];

interface RxSignal<T = void> {
  Connect(callback: (...args: ToTuple<T>) => void): Subscription<T>;
  Wait(): T extends void ? void : T extends unknown[] ? LuaTuple<T> : T;
  Once(callback: (...args: ToTuple<T>) => void): Subscription<T>;
}

interface RxSignalConstructor {
  readonly ClassName: 'RxSignal';
  new <T>(observable: Observable<T> | (() => Observable<T>)): RxSignal<T>;
}

export const RxSignal: RxSignalConstructor;
