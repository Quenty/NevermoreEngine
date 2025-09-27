type Subscription<T> = {
  Fire(...args: T extends unknown[] ? T : [T]): void;
  Fail(): void;
  GetFireFailComplete(): LuaTuple<
    [
      fireCallback: () => void,
      failCallback: () => void,
      completeCallback: () => void
    ]
  >;
  GetFailComplete(): LuaTuple<
    [failCallback: () => void, completeCallback: () => void]
  >;
  Complete(): void;
  IsPending(): boolean;
  Destroy(): void;
  Disconnect(): void;
};

interface SubscriptionConstructor {
  readonly ClassName: 'Subscription';
  new <T extends unknown[]>(
    fireCallback: () => void,
    failCallback: () => void,
    completeCallback: () => void,
    observableSource?: string
  ): Subscription<T>;
}

export const Subscription: SubscriptionConstructor;
