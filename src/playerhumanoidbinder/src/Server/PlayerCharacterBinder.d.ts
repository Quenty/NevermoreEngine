import { Binder } from '@quenty/binder';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

export interface PlayerCharacterBinder<T> extends Omit<Binder<T>, 'Init'> {
  Init(serviceBag: ServiceBag): void;
  SetAutomaticTagging(shouldTag: boolean): void;
  ObserveAutomaticTagging(): Observable<boolean>;
  ObserveAutomaticTaggingBrio(
    predicate?: (value: boolean) => boolean
  ): Observable<Brio<boolean>>;
}

interface PlayerCharacterBinderConstructor {
  readonly ClassName: 'PlayerCharacterBinder';
  new <T>(
    tag: string,
    constructor: { new (...args: unknown[]): T },
    ...args: unknown[]
  ): PlayerCharacterBinder<T>;
}

export const PlayerCharacterBinder: PlayerCharacterBinderConstructor;
