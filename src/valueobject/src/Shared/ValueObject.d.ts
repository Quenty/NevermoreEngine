import { Brio } from '../../../brio';
import { MaidTask } from '../../../maid/src/Shared/Maid';
import { Observable } from '../../../rx';
import { Signal } from '../../../signal/src/Shared/Signal';

type CheckType = string | ((value: any) => LuaTuple<[boolean, string?]>);

interface ValueObject<T> {
  Value: T;
  Changed: Signal<T>;
  GetCheckType: () => CheckType | undefined;
  Mount: (value: T | Observable<[T]>) => MaidTask;
  Observe: () => Observable<[T]>;
  ObserveBrio: (condition?: (value: T) => boolean) => Observable<Brio<T>>;
  SetValue: (value: T) => void;
  Destroy: () => void;
}

interface ValueObjectConstructor {
  readonly ClassName: 'ValueObject';
  new <T>(value: T, checkType?: CheckType): ValueObject<T>;

  fromObservable: <T>(observable: Observable<T>) => ValueObject<T>;
  isValueObject: (value: any) => value is ValueObject<any>;
}

export const ValueObject: ValueObjectConstructor;
