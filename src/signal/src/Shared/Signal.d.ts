type ToTuple<T> = T extends unknown[] ? T : [T];

export type SignalLike<T = void> =
  | Signal<T>
  | RBXScriptSignal<(...args: ToTuple<T>) => void>;

interface Signal<T = void> {
  Fire(...args: ToTuple<T>): void;
  Connect(callback: (...args: ToTuple<T>) => void): RBXScriptConnection;
  DisconnectAll(): void;
  Wait(): T extends void ? void : T extends unknown[] ? LuaTuple<T> : T;
  Once(callback: (...args: ToTuple<T>) => void): RBXScriptConnection;
  Destroy(): void;
}

interface SignalConstructor {
  readonly ClassName: 'Signal';
  isSignal: (value: unknown) => value is Signal<unknown>;
  new <T>(): Signal<T>;
}

export const Signal: SignalConstructor;
