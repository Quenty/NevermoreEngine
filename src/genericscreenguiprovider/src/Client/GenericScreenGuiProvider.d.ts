import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';
import { Mountable } from '@quenty/valueobject';

interface GenericScreenGuiProvider<T extends Record<string, number> | unknown> {
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  ObserveScreenGui(orderName: keyof T): Observable<ScreenGui | Frame>;
  SetDisplayOrder(orderName: keyof T, order: Mountable<number>): () => void;
  Get(orderName: keyof T): ScreenGui | Frame;
  GetDisplayOrder(orderName: keyof T): number;
  ObserveDisplayOrder(orderName: keyof T): Observable<number>;
  Destroy(): void;
}

interface GenericScreenGuiProviderConstructor {
  readonly ClassName: 'GenericScreenGuiProvider';
  readonly ServiceName: 'GenericScreenGuiProvider';
  new <T extends Record<string, number>>(
    orders: T
  ): GenericScreenGuiProvider<T>;
}

export const GenericScreenGuiProvider: GenericScreenGuiProviderConstructor;
