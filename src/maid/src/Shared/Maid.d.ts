interface Destroyable {
    Destroy(): void;
}
export type MaidTask = (() => any) | thread | RBXScriptConnection | Maid | Destroyable;

declare type Maid = {
	[index in number | string]: MaidTask | undefined;
} & {
	GiveTask(task: MaidTask): number;
	DoCleaning(): void;
	Destroy(): void;
}

declare interface MaidConstructor {
	readonly ClassName: "Maid";
	new (): Maid;
}

export declare const Maid: MaidConstructor;