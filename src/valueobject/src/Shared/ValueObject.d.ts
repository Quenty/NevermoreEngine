import { MaidTask } from "../../../maid/src/Shared/Maid";

type CheckType = string | ((value: any) => LuaTuple<[boolean, string?]>);

declare interface ValueObject<T> {
    Value: T;
    GetCheckType: () => CheckType | undefined;
    Mount: (value: T | Observable<T>) => MaidTask;
    Observe: () => Observable<T>;
    ObserveBrio: (condition?: (value: T) => boolean) => Observable<Brio<T>>;
    SetValue: (value: T) => void;
    Destroy: () => void;
}

declare interface ValueObjectConstructor {
    readonly ClassName: string;
    new <T>(value: T, checkType?: CheckType): ValueObject<T>;

    fromObservable: <T>(observable: Observable<T>) => ValueObject<T>;
    isValueObject: (value: any) => value is ValueObject<any>;
}

export declare const ValueObject: ValueObjectConstructor;