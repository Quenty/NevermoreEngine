import { Observable } from './Observable';
import { ToTuple } from './Rx';
import { Subscription } from './Subscription';

type ObservableSubscriptionTable<T = void> = {
  Fire(key: unknown, ...values: ToTuple<T>): void;
  HasSubscriptions(key: unknown): boolean;
  Compelte(key: unknown): void;
  Fail(key: unknown): void;
  Observe(
    key: unknown,
    callback?: (sub: Subscription<T>) => void
  ): Observable<T>;
  Destroy(): void;
};

interface ObservableSubscriptionTableConstructor {
  readonly ClassName: 'ObservableSubscriptionTable';
  new <T>(): ObservableSubscriptionTable<T>;

  DEAD: ObservableSubscriptionTable;
}

export const ObservableSubscriptionTable: ObservableSubscriptionTableConstructor;
