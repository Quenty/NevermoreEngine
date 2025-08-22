type ToTuple<T> = T extends unknown[] ? T : [T];

interface Signal<T = void> {
  Fire(...args: ToTuple<T>): void;
  Connect(callback: (...args: ToTuple<T>) => void): RBXScriptConnection;
  DisconnectAll(): void;
  Wait(): T extends void ? void : T extends any[] ? LuaTuple<T> : T;
  Once(callback: (...args: ToTuple<T>) => void): RBXScriptConnection;
  Destroy(): void;
}

interface SignalConstructor {
  readonly ClassName: 'Signal';
  isSignal: (value: any) => value is Signal<any>;
  new <T>(): Signal<T>;
}

export const Signal: SignalConstructor;
