interface Destroyable {
  Destroy(): void;
}
export type MaidTask =
  | (() => any)
  | thread
  | RBXScriptConnection
  | Maid
  | Destroyable;

type Maid = {
  [index in number | string]: MaidTask | undefined;
} & {
  GiveTask(task: MaidTask): number;
  DoCleaning(): void;
  Destroy(): void;
};

interface MaidConstructor {
  readonly ClassName: 'Maid';
  new (): Maid;
}

export const Maid: MaidConstructor;
