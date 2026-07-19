type ToTuple<T> = [T] extends [LuaTuple<infer V>] ? V : [T];

export type SignalLike<T = void> =
  | Signal<T>
  | RBXScriptSignal<(...args: T extends LuaTuple<infer V> ? V : [T]) => void>;

export interface SignalConnection {
  IsConnected(): boolean;
  Disconnect(): void;
  Destroy(): void;
}

export interface Signal<T = void> {
  Fire(...args: ToTuple<T>): void;
  Connect(callback: (...args: ToTuple<T>) => void): SignalConnection;
  DisconnectAll(): void;
  Wait(): [T] extends [void]
    ? void
    : T extends LuaTuple<infer U>
      ? LuaTuple<U>
      : T;
  Once(callback: (...args: ToTuple<T>) => void): SignalConnection;
  Destroy(): void;
}

interface SignalConstructor {
  readonly ClassName: 'Signal';
  isSignal: (value: unknown) => value is Signal<unknown>;
  new <T = void>(): Signal<T>;
}

export const Signal: SignalConstructor;

export {};
