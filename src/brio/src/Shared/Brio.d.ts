import { Maid } from "../../../maid";

declare type Brio<T extends unknown[] = unknown[]> = {
    Kill(): void;
    IsDead(): boolean;
    GetDiedSignal(): RBXScriptSignal;
    ErrorIfDead(): void;
    ToMaid(): Maid;
    ToMaidAndValue(): LuaTuple<[Maid, ...T]>;
    GetValue(): LuaTuple<[...T]>;
    GetPackedValues(): {
        n: number;
        [index: number]: T;
    },

    Destroy(): void;
}

declare interface BrioConstructor {
	readonly ClassName: "Brio";
	new <T extends unknown[] = unknown[]>(...values: T): Brio<T>;

    DEAD: Brio;
}

export declare const Brio: BrioConstructor;